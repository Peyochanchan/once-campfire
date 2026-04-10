require "test_helper"

class Message::ThreadTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @room = rooms(:watercooler)
    @parent = @room.messages.create!(creator: users(:david), body: "Parent message", client_message_id: "parent-1")
  end

  test "message can have replies" do
    reply = @room.messages.create!(creator: users(:jason), body: "A reply", client_message_id: "reply-1", parent_message_id: @parent.id)

    assert_equal @parent, reply.parent_message
    assert_includes @parent.replies, reply
  end

  test "reply? returns true for replies" do
    reply = @room.messages.create!(creator: users(:jason), body: "A reply", client_message_id: "reply-1", parent_message_id: @parent.id)

    assert reply.reply?
    assert_not @parent.reply?
  end

  test "thread? returns true when message has replies" do
    assert_not @parent.thread?

    @room.messages.create!(creator: users(:jason), body: "A reply", client_message_id: "reply-1", parent_message_id: @parent.id)

    assert @parent.thread?
  end

  test "replies_count returns number of replies" do
    assert_equal 0, @parent.replies_count

    @room.messages.create!(creator: users(:jason), body: "Reply 1", client_message_id: "reply-1", parent_message_id: @parent.id)
    @room.messages.create!(creator: users(:david), body: "Reply 2", client_message_id: "reply-2", parent_message_id: @parent.id)

    assert_equal 2, @parent.replies_count
  end

  test "destroying parent destroys replies" do
    @room.messages.create!(creator: users(:jason), body: "Reply", client_message_id: "reply-1", parent_message_id: @parent.id)

    assert_difference "Message.count", -2 do
      @parent.destroy
    end
  end

  test "root_messages excludes replies" do
    reply = @room.messages.create!(creator: users(:jason), body: "Reply", client_message_id: "reply-1", parent_message_id: @parent.id)

    assert_includes @room.messages.root_messages, @parent
    assert_not_includes @room.messages.root_messages, reply
  end
end
