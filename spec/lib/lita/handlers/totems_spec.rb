require "spec_helper"

describe Lita::Handlers::Totems, lita: true do
  it { routes("#{robot.mention_name}: totems add").to(:add) }
  it { routes("#{robot.mention_name}: totems yield").to(:yield) }
  it { routes("#{robot.mention_name}: totems kick").to(:kick) }
  it { routes("#{robot.mention_name}: totems foo").to(:list) }
  it { routes("#{robot.mention_name}: totems").to(:list) }

  describe "#list" do
    before do
      allow_any_instance_of(described_class).to receive(
        :queue_names
      ).and_return(["foo", "bar"])
    end

    it "lists all queues when called without arguments" do
      expect_reply <<-REPLY.chomp
*** FOO ***
(empty)
*** BAR ***
(empty)
REPLY
      send_test_message("#{robot.mention_name}: totems")
    end

    it "lists only the requested queue when called with a valid queue name" do
      expect_reply <<-REPLY.chomp
*** FOO ***
(empty)
REPLY
      send_test_message("#{robot.mention_name}: totems foo")
    end

    it "lists all queues if the requested queue is not valid" do
      expect_reply <<-REPLY.chomp
*** FOO ***
(empty)
*** BAR ***
(empty)
REPLY
      send_test_message("#{robot.mention_name}: totems invalid")
    end
  end
end
