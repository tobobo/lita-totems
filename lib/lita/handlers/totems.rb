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

        queues.each do |queue|
          output << "*** #{queue[:name].upcase} ***"
          if queue[:items].empty?
            output << "(empty)"
          else
            queue[:items].each_with_index do |item, index|
              output << "#{index + 1}. #{item[:user].name} - Joined #{queued_at}"
            end
          end
        end

        reply output.join("\n")
      end

      private

      def all_queues
        queue_names.map do |name|
          { name: name, items: items_for(name) }
        end
      end

      def items_for(name)
        redis.zrange("queues:#{name}", 0, -1, with_scores: true).map do |item|
          { user: User.find_by_id(item[0]), queued_at: item[1].to_i }
        end
      end

      def queue_by_name(name)
        queues = all_queues.find { |queue| queue[:name] == name.to_s.downcase }
        case queues
        when Array
          queues
        when nil
          []
        else
          [queues]
        end
      end

      def queue_names
        redis.smembers("queues")
      end
    end
  end
end
