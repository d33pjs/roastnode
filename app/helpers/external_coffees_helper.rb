module ExternalCoffeesHelper
  def external_coffee_price(coffee)
    return t("external_coffees.show.unknown") if coffee.price.blank?

    profile_money(coffee.price, coffee.currency)
  end

  def external_coffee_acidity_label(value)
    t("external_coffees.taste.acidity.#{value}")
  end

  def external_coffee_intensity_label(value)
    t("external_coffees.taste.intensity.#{value}")
  end

  def external_coffee_rating_marks(coffee)
    return t("external_coffees.show.no_rating") if coffee.rating.blank?

    filled = "●" * coffee.rating
    empty = "○" * (5 - coffee.rating)
    "#{filled}#{empty}"
  end
end
