class Autocompletable::UsersController < ApplicationController
  GLOBAL_SCOPES = %w[ everyone here channel ].freeze

  def index
    set_page_and_extract_portion_from find_autocompletable_users.with_attached_avatar.ordered, per_page: 20
    @global_mentions = matching_global_mentions
  end

  private
    def find_autocompletable_users
      params[:query].present? ? users_scope.active.filtered_by(params[:query]) : users_scope.active
    end

    def users_scope
      params[:room_id].present? ? Current.user.rooms.find(params[:room_id]).users : User.visible_to(Current.user)
    end

    def matching_global_mentions
      return [] if params[:room_id].blank?

      room = Current.user.rooms.find_by(id: params[:room_id])
      return [] if room.nil? || room.direct?

      query = params[:query].to_s.downcase
      GLOBAL_SCOPES.select { |scope| query.blank? || scope.start_with?(query) }
    end
end
