require "lita/handlers/totems/queue_item"

module Lita
  module Handlers
    class Totems < Handler
      class Totem
        class TotemNameRequired < StandardError; end
        class UserNotQueued < StandardError; end
        class EmptyQueue < StandardError; end

        attr_reader :redis, :name
        private :redis

        class << self
          def all(redis)
            redis.smembers("queues").map do |name|
              new(redis, name)
            end
          end
        end

        def initialize(redis, totem_name)
          @redis = redis
          @name = totem_name.to_s.downcase.strip
          raise TotemNameRequired if name.length == 0
        end

        def add(user)
          redis.zadd("queues:#{name}", Time.now.to_i, user.id)
        end

        def create
          redis.sadd("queues", name)
        end

        def each
          queue.each_with_index do |queue_item, index|
            yield queue_item, index + 1
          end
        end

        def empty?
          queue.empty?
        end

        def destroy
          redis.srem("queues:#{name}", name)
          redis.srem("queues", name)
        end

        def holder
          queue.first.user unless queue.empty?
        end

        def kick(user)
          if queue.empty?
            raise EmptyQueue
          elsif user && !in_queue?(user)
            raise UserNotQueued
          elsif !user
            user = holder
          end

          redis.zrem("queues:#{name}", user.id)
          update_holder
          user
        end

        def persisted?
          redis.sismember("queues", name)
        end

        def to_s
          name.upcase
        end

        def yield(user)
          result = redis.zrem("queues:#{name}", user.id)
          update_holder
          result
        end

        private

        def in_queue?(user)
          queue.find { |queue_item| queue_item.user == user }
        end

        def queue
          redis.zrevrange(
            "queues:#{name}",
            0,
            -1,
            with_scores: true
          ).each_with_index.map do |item, index|
            QueueItem.new(item[0], item[1], index + 1)
          end
        end

        def update_holder
          new_holder = holder
          add(new_holder) if new_holder
        end
      end
    end
  end
end
