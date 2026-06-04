require "test_helper"

class EmailNotification::BundleTest < ActiveSupport::TestCase
  test "returns nil for empty message_ids" do
    assert_nil EmailNotification::Bundle.build(user: users(:kevin), message_ids: [])
  end

  test "returns nil when none of the messages still exist" do
    assert_nil EmailNotification::Bundle.build(user: users(:kevin), message_ids: [ -1, -2 ])
  end

  test "single-message subject uses single key" do
    message = create_message(rooms(:designers), users(:david))

    context = EmailNotification::Bundle.build(user: users(:kevin), message_ids: [ message.id ])

    assert_includes context.subject, "David"
    assert_includes context.subject, "Designers"
    assert_equal 1, context.total_count
    assert_equal 1, context.rooms.size
  end

  test "single-message DM subject uses single_dm key" do
    message = create_message(rooms(:david_and_kevin), users(:david))

    context = EmailNotification::Bundle.build(user: users(:kevin), message_ids: [ message.id ])

    assert_includes context.subject, "David"
    assert_includes context.subject.downcase, "direct"
  end

  test "multiple messages in one room use one_room_multi key" do
    m1 = create_message(rooms(:designers), users(:david))
    m2 = create_message(rooms(:designers), users(:david))
    m3 = create_message(rooms(:designers), users(:david))

    context = EmailNotification::Bundle.build(user: users(:kevin), message_ids: [ m1.id, m2.id, m3.id ])

    assert_includes context.subject, "3"
    assert_includes context.subject, "Designers"
    assert_equal 3, context.total_count
    assert_equal 1, context.rooms.size
  end

  test "multiple messages across rooms use multi key" do
    m_designers = create_message(rooms(:designers), users(:david))
    m_hq        = create_message(rooms(:hq), users(:david))

    context = EmailNotification::Bundle.build(user: users(:kevin), message_ids: [ m_designers.id, m_hq.id ])

    assert_includes context.subject, "2"
    assert_equal 2, context.total_count
    assert_equal 2, context.rooms.size
  end

  private
    def create_message(room, creator)
      room.messages.create!(body: "Hello", client_message_id: SecureRandom.uuid, creator: creator)
    end
end
