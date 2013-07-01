require "lita"

module Lita
  module Handlers
    class Totems < Handler
      class InvalidInvocation < StandardError; end

      route(/^totems\s+add/, to: :add, command: true, help: {
        "totems add TOTEM" => "Add yourself to the queue for the TOTEM."
      })
      route(/^totems\s+yield/, to: :yield, command: true, help: {
        "totems yield TOTEM" => "Yield TOTEM to the next user in the queue."
      })
      route(/^totems\s+kick/, to: :kick, command: true, help: {
        "totems kick TOTEM [USER]" => <<-HELP.chomp
Forcefully remove either USER or the first user from the queue for TOTEM.
HELP
      })
      route(
        /^totems\s+create/,
        to: :create,
        command: true,
        restrict_to: :totem_admins,
        help: { "totems create TOTEM" => "Create a new totem called TOTEM." }
      )
      route(
        /^totems\s+destroy/,
        to: :destroy,
        command: true,
        restrict_to: :totem_admins,
        help: { "totems destroy TOTEM" => "Destroy the TOTEM totem." }
      )
      route(/^totems/, to: :list, command: true, help: {
        "totems [TOTEM]" => "List the queues for all totems, or only TOTEM."
      })

      def add(matches)
        validate_format("Format: #{robot.mention_name} totems add TOTEM_NAME")

        if redis.zadd("queues:#{@queue_name}", Time.now.to_i, user.id)
          reply <<-REPLY.chomp
#{user.name} has been added to the queue for #{@queue_name.upcase}.
REPLY
        else
          reply "#{user.name} is already queued for #{@queue_name.upcase}."
        end
      rescue InvalidInvocation
      end

      def yield(matches)
        validate_format("Format: #{robot.mention_name} totems yield TOTEM_NAME")

        if redis.zrem("queues:#{@queue_name}", user.id)
          reply "#{user.name} has yielded #{@queue_name.upcase}."
        else
          reply "#{user.name} is not queued for #{@queue_name.upcase}."
        end
      rescue InvalidInvocation
      end

      def kick(matches)
        validate_format(
          "Format: #{robot.mention_name} totems kick TOTEM_NAME [USER]"
        )

        items = get_queue_items(@queue_name)

        target_user_name = args[2]

        if target_user_name
          user = User.find_by_name(target_user_name)

          unless user && user_in_queue?(user, items)
            reply "#{target_user_name} is not queued for #{@queue_name.upcase}."
            return
          end
        else
          user = items.first[:user]
        end

        redis.zrem("queues:#{@queue_name}", user.id)
        reply "#{user.name} was kicked from #{@queue_name.upcase}."
      rescue InvalidInvocation
      end

      def list(matches)
        queues = determine_queues(args[0])
        return unless queues
        output = []

        queues.each do |queue|
          output << "*** #{queue[:name].upcase} ***"
          if queue[:items].empty?
            output << "(empty)"
          else
            queue[:items].each_with_index do |item, index|
              output << entry(index + 1, item)
            end
          end
        end

        reply output.join("\n")
      end

      def create(matches)
        validate_format(
          "Format: #{robot.mention_name} totems create TOTEM_NAME",
          false
        )

        if redis.sadd("queues", @queue_name)
          reply "Created totem #{@queue_name.upcase}."
        else
          reply "Totem #{@queue_name.upcase} already exists."
        end
      rescue InvalidInvocation
      end

      private

      def all_queues
        queue_names.map do |name|
          { name: name, items: items_for(name) }
        end
      end

      def determine_queues(queue_name)
        if queue_name && respond_to?(queue_name.downcase.to_s)
          nil
        elsif queue_name
          queue_by_name(queue_name) || all_queues
        else
          all_queues
        end
      end

      def entry(number, item)
        "#{number}. #{item[:user].name} #{waiting_since(item[:waiting_since])}"
      end

      def get_queue_items(queue_name)
        items = queue_by_name(queue_name).first[:items]

        if items.empty?
          reply "#{@queue_name.upcase} is already empty."
          raise InvalidInvocation
        end

        items
      end

      def waiting_since(time_joined)
        "(waiting since #{Time.at(time_joined)})"
      end

      def items_for(name)
        redis.zrange("queues:#{name}", 0, -1, with_scores: true).map do |item|
          { user: User.find_by_id(item[0]), waiting_since: item[1].to_i }
        end
      end

      def queue_by_name(name)
        queues = all_queues.find { |queue| queue[:name] == name.to_s.downcase }
        queues = [queues] unless queues.nil? || queues === Array
        queues
      end

      def queue_names
        redis.smembers("queues")
      end

      def user_in_queue?(user, items)
        items.find { |item| item[:user].name == user.name }
      end

      def validate_format(format, totem_must_exist = true)
        @queue_name = (args[1] || "").to_s.downcase

        if @queue_name.empty?
          reply format
          raise InvalidInvocation
        elsif totem_must_exist && !queue_names.include?(@queue_name)
          reply "There is no totem named #{@queue_name.upcase}."
          raise InvalidInvocation
        end
      end
    end
  end
end
