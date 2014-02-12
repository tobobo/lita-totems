require "lita"
require "lita/handlers/totems/totem"

module Lita
  module Handlers
    class Totems < Handler
      class InvalidInvocation < StandardError; end

      route(/^totems\s+add/, :add, command: true, help: {
        "totems add TOTEM" => "Add yourself to the queue for the TOTEM."
      })
      route(/^totems\s+yield/, :yield, command: true, help: {
        "totems yield TOTEM" => "Yield TOTEM to the next user in the queue."
      })
      route(/^totems\s+kick/, :kick, command: true, help: {
        "totems kick TOTEM [USER]" => <<-HELP.chomp
Forcefully remove either USER or the first user from the queue for TOTEM.
HELP
      })
      route(
        /^totems\s+create/,
        :create,
        command: true,
        restrict_to: :totem_admins,
        help: { "totems create TOTEM" => "Create a new totem called TOTEM." }
      )
      route(
        /^totems\s+destroy/,
        :destroy,
        command: true,
        restrict_to: :totem_admins,
        help: { "totems destroy TOTEM" => "Destroy the TOTEM totem." }
      )
      route(/^totems/, :list, command: true, help: {
        "totems [TOTEM]" => "List the queues for all totems, or only TOTEM."
      })

      def add(response)
        validate_format(
          response,
          "Format: #{robot.mention_name} totems add TOTEM_NAME"
        )

        if @totem.add(response.user)
          if @totem.holder == response.user
            response.reply "#{response.user.name} is now in possession of #{@totem}."
          else
            response.reply <<-REPLY.chomp
#{response.user.name} has been added to the queue for #{@totem}.
REPLY
          end
        else
          response.reply "#{response.user.name} is already queued for #{@totem}."
        end
      rescue InvalidInvocation
      end

      def yield(response)
        validate_format(
          response,
          "Format: #{robot.mention_name} totems yield TOTEM_NAME"
        )

        current_holder = @totem.holder
        if @totem.yield(response.user)
          response.reply "#{response.user.name} has yielded #{@totem}."
          holder = @totem.holder
          notify(holder, "You are now in possession of #{@totem}.") if holder && holder != current_holder
        else
          response.reply "#{response.user.name} is not queued for #{@totem}."
        end
      rescue InvalidInvocation
      end

      def kick(response)
        validate_format(
          response,
          "Format: #{robot.mention_name} totems kick TOTEM_NAME [USER]"
        )

        user_name = response.args[2]
        kick_user = user_name && User.find_by_name(user_name)
        if user_name && !kick_user
          response.reply "There is no such user as #{user_name}"
          return
        end
        initial_holder = @totem.holder
        kick_user = @totem.kick(kick_user)
        response.reply <<-REPLY
#{kick_user.name} was kicked from the queue for #{@totem}.
REPLY
        notify(kick_user, "You've been kicked out of the queue for #{@totem}.")
        holder = @totem.holder
        if holder && holder != initial_holder
          notify(holder, "You are now in possession of #{@totem}.")
        end
      rescue Totem::EmptyQueue
        response.reply "#{@totem} is already empty."
      rescue Totem::UserNotQueued
        response.reply "#{response.user.name} is not queued for #{@totem}."
      rescue InvalidInvocation
      end

      def list(response)
        totems = determine_totems(response.args[0])
        return unless totems
        output = []

        totems.each do |totem|
          output << "*** #{totem} ***"
          if totem.empty?
            output << "(empty)"
          else
            totem.each do |queue_item|
              output << queue_item.to_s
            end
          end
        end

        if output.empty?
          response.reply "There are no totems yet."
        else
          response.reply output.join("\n")
        end
      end

      def create(response)
        validate_format(
          response,
          "Format: #{robot.mention_name} totems create TOTEM_NAME",
          false
        )

        if respond_to?(@totem.name)
          response.reply "Can't create a totem with the name of a subcommand."
          return
        end

        if @totem.create
          response.reply "Created totem #{@totem}."
        else
          response.reply "Totem #{@totem} already exists."
        end
      rescue InvalidInvocation
      end

      def destroy(response)
        validate_format(
          response,
          "Format: #{robot.mention_name} totems destroy TOTEM_NAME"
        )

        @totem.destroy
        response.reply "Destroyed totem #{@totem}."
      rescue InvalidInvocation
      end

      private

      def determine_totems(totem_name)
        return if respond_to?(totem_name.to_s.downcase.strip)

        totems = Totem.all(redis)

        if totem_name
          filtered_totems = totems.select { |totem| totem.name == totem_name }
          totems = filtered_totems unless filtered_totems.empty?
        end

        totems
      end

      def notify(target_user, body)
        source = Source.new(user: target_user)
        robot.send_message(source, body)
      end

      def validate_format(response, format, totem_must_exist = true)
        @totem = Totem.new(redis, response.args[1])

        if totem_must_exist && !@totem.persisted?
          response.reply "There is no totem named #{@totem}."
          raise InvalidInvocation
        end
      rescue Totem::TotemNameRequired
        response.reply format
        raise InvalidInvocation
      end
    end

    Lita.register_handler(Totems)
  end
end
