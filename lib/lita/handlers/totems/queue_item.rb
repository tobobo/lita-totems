module Lita
  module Handlers
    class Totems < Handler
      class QueueItem
        attr_reader :user, :joined_at, :rank

        def initialize(user_id, joined_at, rank)
          @user = User.find_by_id(user_id)
          @joined_at = joined_at.to_i
          @rank = rank
        end

        def to_s
          "#{rank}. #{user.name} (waiting since #{waiting_since})"
        end

        private

        def waiting_since
          Time.at(joined_at)
        end
      end
    end
  end
end
