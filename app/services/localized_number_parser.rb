class LocalizedNumberParser
  UNIT_SUFFIX_PATTERN = /(?:g|grams?|°?c|celsius|eur|€)/i
  NUMBER_WITH_OPTIONAL_UNIT_PATTERN = /\A\s*(?<number>[+-]?(?:\d[\d.,\s]*|[.,]\d+))\s*#{UNIT_SUFFIX_PATTERN}?\s*\z/

  def self.normalize_decimal(value)
    new.normalize_decimal(value)
  end

  def normalize_decimal(value)
    return value unless value.is_a?(String)

    match = value.match(NUMBER_WITH_OPTIONAL_UNIT_PATTERN)
    return value unless match

    normalize_separators(match[:number])
  end

  private
    def normalize_separators(number)
      compacted = number.delete(" ")
      comma_index = compacted.rindex(",")
      dot_index = compacted.rindex(".")

      if comma_index && dot_index
        comma_index > dot_index ? compacted.delete(".").tr(",", ".") : compacted.delete(",")
      elsif comma_index
        compacted.tr(",", ".")
      else
        compacted
      end
    end
end
