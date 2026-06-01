class Users::PushSubscriptions::TestNotificationsController < ApplicationController
  before_action :set_push_subscription

  def create
    WebPush::Notification.deliver(**@push_subscription.notification_params(title: "Campfire Test", body: Random.uuid, path: user_push_subscriptions_url))
    redirect_to user_push_subscriptions_url
  end

  private
    def set_push_subscription
      @push_subscription = Current.user.push_subscriptions.find(params[:push_subscription_id])
    end
end
