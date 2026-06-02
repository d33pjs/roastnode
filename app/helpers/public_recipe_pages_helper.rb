module PublicRecipePagesHelper
  def public_recipe_unknown_label
    t("public_recipe_pages.show.unknown")
  end

  def public_recipe_snapshot_grams(value)
    return public_recipe_unknown_label if value.blank?

    "#{public_recipe_snapshot_decimal(value)}g"
  end

  def public_recipe_snapshot_temperature(value)
    return public_recipe_unknown_label if value.blank?

    "#{public_recipe_snapshot_decimal(value)}°C"
  end

  def public_recipe_snapshot_seconds(value)
    return public_recipe_unknown_label if value.blank?

    "#{value}s"
  end

  def public_recipe_link_label(link)
    link["label"].presence || t("public_recipe_pages.show.#{link["kind"]}", default: t("public_recipe_pages.show.info"))
  end

  private
    def public_recipe_snapshot_decimal(value)
      number_with_precision(
        value.to_d,
        precision: 1,
        strip_insignificant_zeros: true,
        separator: ".",
        delimiter: ","
      )
    end
end
