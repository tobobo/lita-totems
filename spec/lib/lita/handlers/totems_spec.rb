require "spec_helper"

describe Lita::Handlers::Totems, lita: true do
  it { routes_command("totems add").to(:add) }
  it { routes_command("totems yield").to(:yield) }
  it { routes_command("totems kick").to(:kick) }
  it { routes_command("totems foo").to(:list) }
  it { routes_command("totems").to(:list) }

  describe "#list" do
    before do
      allow_any_instance_of(described_class).to receive(
        :queue_names
      ).and_return(["foo", "bar"])
    end

    it "lists all queues when called without arguments" do
      send_command("totems")
      expect(replies.last).to eq <<-REPLY.chomp
*** FOO ***
(empty)
*** BAR ***
(empty)
REPLY
    end

    it "lists only the requested queue when called with a valid queue name" do
      send_command("totems foo")
      expect(replies.last).to eq <<-REPLY.chomp
*** FOO ***
(empty)
REPLY
    end

    it "lists all queues if the requested queue doesn't exist" do
      send_command("totems invalid")
      expect(replies.last).to eq <<-REPLY.chomp
*** FOO ***
(empty)
*** BAR ***
(empty)
REPLY
    end

    it "doesn't respond if the requested queue is the same as a subcommand" do
      send_command("totems add")
      replies.each { |reply| expect(reply).not_to include("*** FOO ***")}
    end
  end
end
