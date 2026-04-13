class Rooms::InvitationsController < ApplicationController
  include RoomScoped

  before_action :ensure_can_administer_room

  def new
    @invitation = Invitation.new(room: @room)
  end

  def create
    @invitation = Invitation.new(invitation_params.merge(invited_by: Current.user, room: @room))
    if existing_user = User.active.find_by("LOWER(email_address) = ?", @invitation.email.to_s.downcase)
      # User exists — just add them to the room
      @room.memberships.find_or_create_by!(user: existing_user)
      redirect_to edit_room_url_for(@room), notice: I18n.t("invitations.notices.added_existing_user", name: existing_user.name)
    elsif @invitation.save
      InvitationMailer.invite(@invitation).deliver_later
      redirect_to edit_room_url_for(@room), notice: I18n.t("invitations.notices.sent")
    else
      redirect_to edit_room_url_for(@room), alert: @invitation.errors.full_messages.to_sentence
    end
  end

  private
    def edit_room_url_for(room)
      case room
      when Rooms::Open   then edit_rooms_open_path(room)
      when Rooms::Closed then edit_rooms_closed_path(room)
      else                    room_path(room)
      end
    end

    def ensure_can_administer_room
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def invitation_params
      params.require(:invitation).permit(:email)
    end
end
