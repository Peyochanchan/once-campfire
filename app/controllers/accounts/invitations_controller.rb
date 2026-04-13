class Accounts::InvitationsController < ApplicationController
  before_action :ensure_can_administer

  def index
    @invitations = Invitation.ordered.includes(:invited_by, :accepted_user)
  end

  def new
    @invitation = Invitation.new
  end

  def create
    @invitation = Invitation.new(invitation_params.merge(invited_by: Current.user))
    if User.where("LOWER(email_address) = ?", @invitation.email.to_s.downcase).exists?
      @invitation.errors.add(:email, I18n.t("invitations.errors.email_taken"))
      render :new, status: :unprocessable_entity
    elsif @invitation.save
      InvitationMailer.invite(@invitation).deliver_later
      redirect_to account_invitations_path, notice: I18n.t("invitations.notices.sent")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    invitation = Invitation.find(params[:id])
    invitation.revoke!
    redirect_to account_invitations_path, notice: I18n.t("invitations.notices.revoked")
  end

  private
    def invitation_params
      params.require(:invitation).permit(:email, :expires_at, :room_id)
    end
end
