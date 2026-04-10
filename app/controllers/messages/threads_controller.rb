class Messages::ThreadsController < ApplicationController
  before_action :set_message

  def show
    @replies = @message.replies.ordered.with_creator.with_attachment_details.with_boosts
    @room = @message.room
  end

  private
    def set_message
      @message = Message.find(params[:message_id])
    end
end
