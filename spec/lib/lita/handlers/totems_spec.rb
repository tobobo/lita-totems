require "spec_helper"

describe Lita::Handlers::Totems, lita: true do
  it { routes_command("totems add").to(:add) }
  it { routes_command("totems yield").to(:yield) }
  it { routes_command("totems kick").to(:kick) }
  it { routes_command("totems foo").to(:list) }
  it { routes_command("totems").to(:list) }

  before do
    allow_any_instance_of(described_class).to receive(
      :queue_names
    ).and_return(["foo", "bar"])
  end

  describe "#list" do
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

  describe "#add" do
    before do
      allow(Lita::User).to receive(:find_by_id).with("1").and_return(user)
    end

    it "replies with a message saying the user was added" do
      send_command("totems add foo")
      expect(replies.last).to eq(
        "#{user.name} has been added to the queue for FOO."
      )
    end

    it "replies with the required format if a queue name is missing" do
      send_command("totems add")
      expect(replies.last).to match(/^Format:/)
    end

    it "shows the user in subsequent calls to #list" do
      time = Time.now
      allow(Time).to receive(:now).and_return(time)
      send_command("totems add foo")
      send_command("totems foo")
      expect(replies.last).to eq <<-REPLY.chomp
*** FOO ***
1. Test User (waiting since #{time})
REPLY
    end

    it "tells the user if they're already queued" do
      send_command("totems add foo")
      send_command("totems add foo")
      expect(replies.last).to include("already queued")
    end

    it "tells the user if they try to queue for an invalid queue" do
      send_command("totems add invalid")
      expect(replies.last).to include("no totem named INVALID")
    end
  end

  describe "#yield" do
    before do
      allow(Lita::User).to receive(:find_by_id).with("1").and_return(user)
      send_command("totems add foo")
    end

    it "replies with a message saying the user has yielded" do
      send_command("totems yield foo")
      expect(replies.last).to eq("#{user.name} has yielded FOO.")
    end

    it "replies with the required format if a queue name is missing" do
      send_command("totems yield")
      expect(replies.last).to match(/^Format:/)
    end

    it "doesn't show the user in subsequent calls to #list" do
      send_command("totems yield foo")
      send_command("totems foo")
      expect(replies.last).not_to include(user.name)
    end

    it "tells the user if they're not in the queue" do
      send_command("totems yield foo")
      send_command("totems yield foo")
      expect(replies.last).to include("not queued")
    end

    it "tells the user if they try to yield an invalid queue" do
      send_command("totems yield invalid")
      expect(replies.last).to include("no totem named INVALID")
    end
  end
end
