class PublicBeanPagesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_share
  after_action :record_page_view, only: :show
  rate_limit to: 10,
    within: 3.minutes,
    only: :unlock,
    by: -> { "#{request.remote_ip}:#{PublicBeanShare.token_digest_for(params[:token])}" },
    with: -> {
      flash.now[:alert] = t(".rate_limited")
      render :password, status: :too_many_requests
    }

  def show
    return render :password if password_required?

    load_snapshot
    @record_public_bean_view = true
  end

  def unlock
    if @share.authenticate_password(params[:password])
      session[unlock_session_key] = @share.password_unlock_fingerprint
      redirect_to public_bean_page_path(@share.token)
    else
      flash.now[:alert] = t(".failed")
      render :password, status: :unprocessable_entity
    end
  end

  private
    def set_share
      @share = PublicBeanShare.find_enabled_by_token!(params[:token])
      @site_footer_buy_me_a_coffee = @share.workspace.site_footer_buy_me_a_coffee
      @site_footer_show_version = false
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_snapshot
      @snapshot = @share.snapshot
    end

    def record_page_view
      return unless @record_public_bean_view && response.successful?

      PublicBeanShareViewRecorder.new(share: @share, request:).call
    end

    def password_required?
      @share.password_protected? && !share_unlocked?
    end

    def share_unlocked?
      session[unlock_session_key] == @share.password_unlock_fingerprint
    end

    def unlock_session_key
      "public_bean_share:#{@share.token}:unlocked"
    end
end
