class PublicBrewPagesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_share

  def show
    return render :password if password_required?

    load_snapshot
  end

  def unlock
    if @share.authenticate_password(params[:password])
      session[unlock_session_key] = @share.password_unlock_fingerprint
      redirect_to public_brew_page_path(@share.token)
    else
      flash.now[:alert] = t(".failed")
      render :password, status: :unprocessable_entity
    end
  end

  private
    def set_share
      @share = PublicBrewShare.find_enabled_by_token!(params[:token])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_snapshot
      @snapshot = @share.snapshot
    end

    def password_required?
      @share.password_protected? && !share_unlocked?
    end

    def share_unlocked?
      session[unlock_session_key] == @share.password_unlock_fingerprint
    end

    def unlock_session_key
      "public_brew_share:#{@share.token}:unlocked"
    end
end
