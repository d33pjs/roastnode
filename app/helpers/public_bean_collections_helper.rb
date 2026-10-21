module PublicBeanCollectionsHelper
  def collection_decimal(value, precision: 1)
    return t("bean_collections.public.not_rated") if value.blank?

    number_with_precision(value, precision:, strip_insignificant_zeros: true)
  end

  def collection_rating(value)
    return t("bean_collections.public.not_rated") if value.blank?

    "#{collection_decimal(value)} / 5"
  end

  def collection_grams(value)
    return t("bean_collections.public.not_recorded") if value.blank?

    "#{collection_decimal(value)}\u00a0g"
  end

  def collection_date(value)
    return if value.blank?

    l(Date.iso8601(value.to_s), format: t("bean_collections.public.date_format"))
  rescue ArgumentError, TypeError
    nil
  end

  def collection_money(value, currency)
    return if value.blank? || currency.blank?

    "#{number_with_precision(value, precision: 2)} #{currency}"
  end

  def collection_external_url(value)
    uri = URI.parse(value.to_s)
    value if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  def collection_public_path(view)
    if @preview
      preview_public_bean_collection_path(view:)
    else
      public_bean_collection_page_path(token: @collection.token, view:)
    end
  end

  def collection_fact(value)
    Array(value).compact_blank.join(" · ")
  end
end
