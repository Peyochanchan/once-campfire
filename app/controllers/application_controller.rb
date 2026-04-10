class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, BlockBannedRequests, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName

  before_action :set_locale

  private
    def set_locale
      I18n.locale = Current.user&.locale&.to_sym || I18n.default_locale
    end
end
