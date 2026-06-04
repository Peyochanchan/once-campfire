class EmailNotification::DispatchJob < ApplicationJob
  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.nil?

    EmailNotification::Dispatcher.dispatch(message)
  end
end
