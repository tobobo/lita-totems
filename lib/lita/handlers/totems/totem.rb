module Lita
  module Handlers
    class Totems < Handler
      class Totem
        class TotemNameRequired < StandardError; end
        class UserNotQueued < StandardError; end
        class EmptyQueue < StandardError; end

        attr_reader :redis, :name
        private :redis

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

        def destroy
          redis.srem("queues:#{name}", name)
          redis.srem("queues", name)
        end

        def kick(user)
          if queue.empty?
            raise EmptyQueue
          elsif user && !in_queue?(user)
            raise UserNotQueued
          elsif !user
            user = queue.first[:user]
          end

          redis.zrem("queues:#{name}", user.id)
          user
        end

        def persisted?
          redis.sismember("queues", name)
        end

        def to_s
          name.upcase
        end

        def yield(user)
          redis.zrem("queues:#{name}", user.id)
        end

        private

        def in_queue?(user)
          queue.find { |item| item[:user] == user }
        end

        def queue
          redis.zrange("queues:#{name}", 0, -1, with_scores: true).map do |item|
            { user: User.find_by_id(item[0]), waiting_since: item[1].to_i }
          end
        end
      end
    end
  end
end
