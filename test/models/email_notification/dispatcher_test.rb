require "test_helper"

class EmailNotification::DispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "dispatch creates one pending row per candidate and enqueues a DeliveryJob each" do
    # Designers: david (skipped, creator), jason (everything → activity), jz (everything → activity), kevin (mentions, not mentioned → skip)
    message = create_message(rooms(:designers), users(:david))

    assert_difference -> { PendingEmailNotification.count }, +2 do
      assert_enqueued_jobs 2, only: EmailNotification::DeliveryJob do
        EmailNotification::Dispatcher.dispatch(message)
      end
    end

    user_ids = PendingEmailNotification.pluck(:user_id).sort
    assert_equal [ users(:jason).id, users(:jz).id ].sort, user_ids
    assert_equal [ "activity" ], PendingEmailNotification.distinct.pluck(:kind)
  end

  test "dispatch skips room when membership.last_email_notified_at is within cooldown" do
    memberships(:jason_designers).update! last_email_notified_at: 3.minutes.ago
    message = create_message(rooms(:designers), users(:david))

    assert_difference -> { PendingEmailNotification.count }, +1 do
      EmailNotification::Dispatcher.dispatch(message)
    end

    assert_equal [ users(:jz).id ], PendingEmailNotification.pluck(:user_id)
  end

  test "dispatch skips users with email_notifications_enabled = false" do
    users(:jason).update! email_notifications_enabled: false
    message = create_message(rooms(:designers), users(:david))

    EmailNotification::Dispatcher.dispatch(message)

    refute_includes PendingEmailNotification.pluck(:user_id), users(:jason).id
  end

  test "deliver_bundle_for is a no-op when user has no pending rows" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotification::Dispatcher.deliver_bundle_for(users(:kevin).id)
    end
  end

  test "deliver_bundle_for is a no-op when user has recently been seen in the app" do
    message = create_message(rooms(:designers), users(:david))
    PendingEmailNotification.create!(user: users(:kevin), room: rooms(:designers), message: message, kind: "mention")
    users(:kevin).update! last_seen_at: 10.seconds.ago

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotification::Dispatcher.deliver_bundle_for(users(:kevin).id)
    end
  end

  test "deliver_bundle_for is a no-op when user is within per-user cooldown" do
    message = create_message(rooms(:designers), users(:david))
    PendingEmailNotification.create!(user: users(:kevin), room: rooms(:designers), message: message, kind: "mention")
    users(:kevin).update! last_email_notified_at: 30.seconds.ago

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotification::Dispatcher.deliver_bundle_for(users(:kevin).id)
    end
  end

  test "deliver_bundle_for sends a single bundled email, clears pending and touches cooldown" do
    m1 = create_message(rooms(:designers), users(:david))
    m2 = create_message(rooms(:designers), users(:david))
    PendingEmailNotification.create!(user: users(:kevin), room: rooms(:designers), message: m1, kind: "mention")
    PendingEmailNotification.create!(user: users(:kevin), room: rooms(:designers), message: m2, kind: "mention")
    users(:kevin).update! last_seen_at: nil, last_email_notified_at: nil

    assert_difference -> { ActionMailer::Base.deliveries.size }, +1 do
      assert_difference -> { PendingEmailNotification.count }, -2 do
        EmailNotification::Dispatcher.deliver_bundle_for(users(:kevin).id)
      end
    end

    users(:kevin).reload
    assert_not_nil users(:kevin).last_email_notified_at
    membership = memberships(:kevin_designers).reload
    assert_not_nil membership.last_email_notified_at
  end

  test "deliver_bundle_for second call after queue drain is a no-op" do
    message = create_message(rooms(:designers), users(:david))
    PendingEmailNotification.create!(user: users(:kevin), room: rooms(:designers), message: message, kind: "mention")
    users(:kevin).update! last_seen_at: nil, last_email_notified_at: nil

    EmailNotification::Dispatcher.deliver_bundle_for(users(:kevin).id)

    # Reset cooldown for the second pass — we want to test "no pending" not "cooldown".
    users(:kevin).update_column(:last_email_notified_at, nil)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotification::Dispatcher.deliver_bundle_for(users(:kevin).id)
    end
  end

  private
    def create_message(room, creator)
      room.messages.create!(body: "Hello", client_message_id: SecureRandom.uuid, creator: creator)
    end
end
