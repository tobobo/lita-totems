require "lita"

module Lita
  module Handlers
    class Totems < Handler
      route(/^totems\s+add/, to: :add, command: true)
      route(/^totems\s+yield/, to: :yield, command: true)
      route(/^totems\s+kick/, to: :kick, command: true)
      route(/^totems/, to: :list, command: true)

      def add(matches)

      end

      def yield(matches)

      end

      def kick(matches)

      end

      def list(matches)
        queue_name = args[0]
        return if queue_name && ["add", "yield", "kick"].include?(queue_name)

        output = []

        queues = queue_by_name(queue_name) if queue_name
        queues = all_queues if queues.nil? || queues.empty?

        queues.each do |name, item_list|
          output << "*** #{name.upcase} ***"
          if item_list.empty?
            output << "(empty)"
          else
            item_list.each_with_index do |item, index|
              output << "#{index + 1}. #{item[:user].name} (#{time_waited(item[:joined_at])})"
            end
          end
        end

        reply output.join("\n")
      end

      private

      def all_queues
        queue_names.map do |queue_name|
          [queue_name, items_for(queue_name)]
        end
      end

      def items_for(queue_name)
        redis.hgetall("queues:#{queue_name}").map do |user_id, joined_at|
          { user: User.find_by_id(user_id), joined_at: time_since(joined_at) }
        end
      end

      def queue_by_name(queue_name)
        if redis.sismember("queues", queue_name)
          [[queue_name, items_for(queue_name)]]
        end
      end

      def queue_names
        @all_queue_names ||= redis.smembers("queues")
      end

    end
  end
end
