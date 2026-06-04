require "test_helper"

class EmailNotification::PolicyTest < ActiveSupport::TestCase
  test "skips when the membership belongs to the message creator" do
    message = create_message(rooms(:designers), users(:david))
    membership = memberships(:david_designers)

    verdict = EmailNotification::Policy.decide(message: message, membership: membership)

    assert_equal :skip, verdict.action
  end

  test "skips invisible memberships" do
    memberships(:kevin_designers).update! involvement: :invisible
    message = create_message(rooms(:designers), users(:david))

    verdict = EmailNotification::Policy.decide(message: message, membership: memberships(:kevin_designers))

    assert_equal :skip, verdict.action
  end

  test "skips :nothing memberships" do
    memberships(:kevin_designers).update! involvement: :nothing
    message = create_message(rooms(:designers), users(:david))

    verdict = EmailNotification::Policy.decide(message: message, membership: memberships(:kevin_designers))

    assert_equal :skip, verdict.action
  end

  test "enqueues :direct for DM rooms regardless of involvement" do
    message = create_message(rooms(:david_and_kevin), users(:david))

    verdict = EmailNotification::Policy.decide(message: message, membership: memberships(:kevin_david_and_kevin))

    assert_equal :enqueue, verdict.action
    assert_equal :direct,  verdict.kind
  end

  test "enqueues :mention when the membership user is mentioned" do
    message = create_message(rooms(:designers), users(:david), mention: :kevin)

    verdict = EmailNotification::Policy.decide(message: message, membership: memberships(:kevin_designers))

    assert_equal :enqueue, verdict.action
    assert_equal :mention, verdict.kind
  end

  test "enqueues :activity for involved_in_everything memberships" do
    memberships(:kevin_designers).update! involvement: :everything
    message = create_message(rooms(:designers), users(:david))

    verdict = EmailNotification::Policy.decide(message: message, membership: memberships(:kevin_designers))

    assert_equal :enqueue,  verdict.action
    assert_equal :activity, verdict.kind
  end

  test "skips when none of the above (default :mentions involvement, not mentioned, not direct)" do
    message = create_message(rooms(:designers), users(:david))
    # kevin_designers default = :mentions, not mentioned, not a DM

    verdict = EmailNotification::Policy.decide(message: message, membership: memberships(:kevin_designers))

    assert_equal :skip, verdict.action
  end

  private
    def create_message(room, creator, mention: nil)
      body = mention ? "Hello #{mention_attachment_for(mention)}" : "Hello"
      room.messages.create!(body: body, client_message_id: SecureRandom.uuid, creator: creator)
    end
end
