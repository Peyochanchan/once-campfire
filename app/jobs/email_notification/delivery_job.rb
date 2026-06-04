class EmailNotification::DeliveryJob < ApplicationJob
  def perform(user_id)
    EmailNotification::Dispatcher.deliver_bundle_for(user_id)
  end
end
