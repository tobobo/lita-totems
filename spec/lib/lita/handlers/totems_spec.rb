require "spec_helper"

describe Lita::Handlers::Totems, lita: true do
  it { routes_command("totems add").to(:add) }
  it { routes_command("totems yield").to(:yield) }
  it { routes_command("totems kick").to(:kick) }
  it { routes_command("totems foo").to(:list) }
  it { routes_command("totems create").to(:create) }
  it { routes_command("totems destroy").to(:destroy) }
  it { routes_command("totems").to(:list) }

  let(:another_user) { Lita::User.create(2, name: "Another User") }

  before do
    Lita.config.robot.admins = user.id
    Lita::Authorization.add_user_to_group(user, user, "totem_admins")
    send_command("totems create foo")
    send_command("totems create bar")
  end

  describe "#list" do
    it "lists all queues when called without arguments" do
      send_command("totems")
      expect(replies.last).to include("*** FOO ***\n(empty)")
      expect(replies.last).to include("*** BAR ***\n(empty)")
    end

    it "lists only the requested queue when called with a valid queue name" do
      send_command("totems foo")
      expect(replies.last).to include("*** FOO ***\n(empty)")
    end

    it "lists all queues if the requested queue doesn't exist" do
      send_command("totems invalid")
      expect(replies.last).to include("*** FOO ***\n(empty)")
      expect(replies.last).to include("*** BAR ***\n(empty)")
    end

    it "doesn't respond if the requested queue is the same as a subcommand" do
      send_command("totems add")
      replies.each { |reply| expect(reply).not_to include("*** FOO ***")}
    end

    it "lists waiting users in the queues" do
      send_command("totems add foo")
      send_command("totems foo")
      expect(replies.last).to include(user.name)
    end

    it "tells the user if there are no totems yet" do
      send_command("totems destroy foo")
      send_command("totems destroy bar")
      send_command("totems")
      expect(replies.last).to include("no totems yet")
    end
  end

  describe "#add" do
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

    it "notifies the next user in the queue" do
      send_command("totems add foo", as: another_user)
      expect_any_instance_of(described_class).to receive(:notify).with(
        another_user,
        /now in possession/
      )
      send_command("totems yield foo")
    end

    it "does not notify anyone if no one is waiting" do
      expect_any_instance_of(described_class).not_to receive(:notify)
      send_command("totems yield foo")
    end
  end

  describe "#kick" do
    let(:target_user) { Lita::User.create(3, name: "Target User") }

    it "replies with the required format if a queue name is missing" do
      send_command("totems kick")
      expect(replies.last).to match(/^Format:/)
    end

    it "replies with a warning if the queue name is invalid" do
      send_command("totems kick invalid")
      expect(replies.last).to include("no totem named INVALID")
    end

    it "replies with a warning if there is no one in the queue" do
      send_command("totems kick foo")
      expect(replies.last).to include("already empty")
    end

    it "kicks the first user if no user is specified" do
      send_command("totems add foo", as: target_user)
      send_command("totems kick foo")
      expect(replies.last).to include("#{target_user.name} was kicked")
      send_command("totems foo")
      expect(replies.last).not_to include(target_user.name)
    end

    it "replies with a warning if the target user is not in the queue" do
      another_user
      send_command("totems add foo", as: target_user)
      send_command("totems kick foo 'Another User'")
      expect(replies.last).to include("not queued")
    end

    it "replies with a warning if no such user exists" do
      send_command("totems add foo", as: target_user)
      send_command("totems kick foo 'missing user'")
      expect(replies.last).to include("no such user")
    end

    it "kicks the target user" do
      send_command("totems add foo", as: another_user)
      send_command("totems add foo", as: target_user)
      send_command("totems kick foo '#{target_user.name}'")
      expect(replies.last).to include("#{target_user.name} was kicked")
      send_command("totems foo")
      expect(replies.last).not_to include(target_user.name)
    end
  end

  describe "#create" do
    it "requires a totem name" do
      send_command("totems create")
      expect(replies.last).to match(/^Format:/)
    end

    it "creates a totem" do
      send_command("totems create baz")
      expect(replies.last).to include("Created totem")
      send_command("totems baz")
      expect(replies.last).to include("BAZ")
    end

    it "tells the user if the totem already existed" do
      send_command("totems create foo")
      expect(replies.last).to include("already exists")
    end

    it "doesn't allow creation of a totem with the name of a subcommand" do
      send_command("totems create add")
      expect(replies.last).to include("with the name of a subcommand")
    end
  end

  describe "#destroy" do
    it "requires a totem name" do
      send_command("totems destroy")
      expect(replies.last).to match(/^Format:/)
    end

    it "replies with a warning if the queue name is invalid" do
      send_command("totems destroy invalid")
      expect(replies.last).to include("no totem named INVALID")
    end

    it "destroys a totem" do
      send_command("totems destroy foo")
      expect(replies.last).to include("Destroyed totem")
      send_command("totems")
      expect(replies.last).not_to include("FOO")
    end
  end
end
