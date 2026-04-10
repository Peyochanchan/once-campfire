require "test_helper"

class Messages::ThreadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "once.campfire.test"
    sign_in :david

    @room = rooms(:watercooler)
    @parent = @room.messages.create!(creator: users(:david), body: "Thread starter", client_message_id: "thread-parent")
    @reply = @room.messages.create!(creator: users(:jason), body: "Thread reply", client_message_id: "thread-reply", parent_message_id: @parent.id)
  end

  test "show displays thread with parent and replies" do
    get message_thread_url(@parent)

    assert_response :success
    assert_select ".thread-panel__parent", count: 1
    assert_select ".thread-panel__replies .thread-message", count: 1
  end

  test "show displays reply count" do
    get message_thread_url(@parent)

    assert_select ".thread-panel__separator", text: /1 reply/
  end

  test "creating a reply redirects back to thread" do
    post room_messages_url(@room), params: {
      message: { body: "New reply", client_message_id: "new-reply", parent_message_id: @parent.id }
    }

    assert_redirected_to message_thread_path(@parent)
    assert_equal 2, @parent.replies.count
  end

  test "replies do not appear in room root messages" do
    get room_messages_url(@room)

    assert_response :success
    assert_select "##{dom_id(@parent)}", count: 1
    assert_select "##{dom_id(@reply)}", count: 0
  end
end
