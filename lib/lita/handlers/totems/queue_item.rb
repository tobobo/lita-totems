require "chronic_duration"

module Lita
  module Handlers
    class Totems < Handler
      class QueueItem
        attr_reader :user, :time, :rank

        def initialize(user_id, time, rank)
          @user = User.find_by_id(user_id)
          @time = time.to_i
          @rank = rank
        end

        def to_s
          if rank == 1
            "1. #{user.name} (held for #{duration})"
          else
            "#{rank}. #{user.name} (waiting for #{duration})"
          end
        end

        def duration
          ChronicDuration.output(Time.now.to_i - time, format: :short)
        end
      end
    end
  end
end
