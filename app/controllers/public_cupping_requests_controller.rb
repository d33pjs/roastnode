class PublicCuppingRequestsController < ApplicationController
  allow_unauthenticated_access

  around_action :use_browser_locale
  before_action :set_cupping_request
  rate_limit to: 20,
    within: 10.minutes,
    only: :update,
    by: -> { "#{request.remote_ip}:#{CuppingRequest.token_digest_for(params[:token])}" },
    with: -> { render_rate_limited }

  def show
    CuppingRequests::Activate.call(request: @cupping_request, ip_address: request.remote_ip)
    prepare_page
  rescue StandardError => error
    log_unavailable(error)
    head :not_found
  end

  def update
    CuppingRequests::UpdateFeedback.call(
      request: @cupping_request,
      attributes: feedback_params,
      ip_address: request.remote_ip
    )
    redirect_to public_cupping_request_path(@cupping_request.token), notice: t(".saved")
  rescue CuppingRequests::FeedbackClosed
    prepare_page(feedback_values: feedback_params.to_h)
    render :show, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid, CuppingRequests::UpdateFeedback::InvalidFeedback
    @feedback_error = t(".invalid")
    prepare_page(feedback_values: feedback_params.to_h)
    render :show, status: :unprocessable_entity
  rescue CuppingRequests::UpdateFeedback::PersistenceError => error
    log_feedback_unavailable(error)
    @feedback_error = t(".invalid")
    prepare_page(feedback_values: feedback_params.to_h)
    render :show, status: :unprocessable_entity
  end

  private
    def set_cupping_request
      @cupping_request = CuppingRequest.find_by_token!(params[:token])
      @site_footer_show_version = false
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def feedback_params
      params.expect(feedback: %i[taste_balance rating feedback_comment])
    end

    def prepare_page(feedback_values: nil)
      @cupping_request.reload
      @snapshot = @cupping_request.snapshot
      @feedback_open = @cupping_request.feedback_open?
      @feedback_values = feedback_values&.stringify_keys || {
        "taste_balance" => @snapshot.dig("brew", "taste_balance").presence || "unknown",
        "rating" => @snapshot.dig("brew", "rating"),
        "feedback_comment" => @cupping_request.feedback_comment
      }
    end

    def render_rate_limited
      @feedback_error = t(".rate_limited")
      prepare_page(feedback_values: params[:feedback]&.to_unsafe_h)
      render :show, status: :too_many_requests
    end

    def use_browser_locale(&block)
      I18n.with_locale(browser_locale) do
        response.set_header("Content-Language", I18n.locale.to_s)
        yield
      end
    end

    def browser_locale
      supported_preference = accept_language_preferences.find do |preference|
        %w[de en].include?(preference.fetch(:language))
      end

      supported_preference&.fetch(:language) == "de" ? :de : :en
    end

    def accept_language_preferences
      request.headers["Accept-Language"].to_s.split(",").each_with_index.filter_map do |entry, index|
        language_tag, *parameters = entry.strip.split(";")
        language = language_tag.to_s.downcase.split("-").first
        quality_parameter = parameters.find { |parameter| parameter.strip.start_with?("q=") }
        quality = quality_parameter ? Float(quality_parameter.split("=", 2).last) : 1.0
        next if quality <= 0

        { language:, quality:, index: }
      rescue ArgumentError
        nil
      end.sort_by { |preference| [ -preference.fetch(:quality), preference.fetch(:index) ] }
    end

    def log_unavailable(error)
      Rails.logger.info("Public cupping request unavailable: #{error.class}; request_id=#{request.request_id}")
    end

    def log_feedback_unavailable(error)
      Rails.logger.info(
        "Public cupping feedback unavailable: #{error.diagnostic_class}; request_id=#{request.request_id}"
      )
    end
end
