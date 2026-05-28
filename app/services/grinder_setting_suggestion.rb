class GrinderSettingSuggestion
  ParsedSetting = Struct.new(:raw, :format, :coordinate, keyword_init: true)

  TARGET_RATIO = BigDecimal("2.5")
  TARGET_TIME_RANGE = 25..30
  DIAL_TURNS_SIZE = BigDecimal("20")
  MINIMUM_COMPARABLE_BREWS = 2
  SAMPLE_LIMIT = 5

  def self.parse_setting(value)
    raw = value.to_s.strip
    return if raw.blank?

    if (match = raw.match(/\A(?<turn>-?\d+)\s*\/\s*(?<dial>-?\d+(?:[,.]\d+)?)\z/))
      turn = BigDecimal(match[:turn])
      dial = decimal(match[:dial])
      return ParsedSetting.new(raw:, format: :dial_turns, coordinate: (turn * DIAL_TURNS_SIZE) + dial)
    end

    if raw.match?(/\A-?\d+(?:[,.]\d+)?\z/)
      return ParsedSetting.new(raw:, format: :plain_numeric, coordinate: decimal(raw))
    end
  end

  def initialize(bean:, minimum_comparable_brews: MINIMUM_COMPARABLE_BREWS)
    @bean = bean
    @minimum_comparable_brews = minimum_comparable_brews
  end

  def call
    candidates_by_grinder.filter_map do |grinder, candidates|
      build_suggestion(grinder, dominant_format_candidates(candidates))
    end.sort_by { |suggestion| [ -suggestion[:comparable_brew_count], suggestion[:grinder].name ] }
  end

  private
    attr_reader :bean, :minimum_comparable_brews

    def self.decimal(value)
      BigDecimal(value.to_s.tr(",", "."))
    end

    def candidates_by_grinder
      brew_scope.each_with_object({}) do |brew, grouped|
        next unless brew.grinder&.grinder?
        next if brew.dose_grams.blank? || brew.dose_grams.to_d.zero?
        next if brew.beverage_grams.blank? || brew.total_time_seconds.blank?

        parsed_setting = self.class.parse_setting(brew.grind_setting)
        next unless parsed_setting

        grouped[brew.grinder] ||= []
        grouped[brew.grinder] << {
          brew:,
          parsed_setting:,
          ratio: brew.beverage_grams.to_d / brew.dose_grams.to_d,
          total_time_seconds: brew.total_time_seconds,
          rating: brew.rating
        }
      end
    end

    def brew_scope
      bean.workspace.brews.includes(:grinder).where.not(grinder_id: nil)
    end

    def dominant_format_candidates(candidates)
      candidates
        .group_by { |candidate| candidate[:parsed_setting].format }
        .values
        .max_by(&:size) || []
    end

    def build_suggestion(grinder, candidates)
      return if candidates.size < minimum_comparable_brews

      ranked_candidates = candidates.sort_by { |candidate| score(candidate) }
      sample = ranked_candidates.first(SAMPLE_LIMIT)

      {
        grinder:,
        suggested_setting: ranked_candidates.first[:parsed_setting].raw,
        setting_format: ranked_candidates.first[:parsed_setting].format,
        comparable_brew_count: candidates.size,
        sample_brew_count: sample.size,
        average_ratio: rounded_average(sample.map { |candidate| candidate[:ratio] }, precision: 2),
        average_total_time_seconds: rounded_average(sample.map { |candidate| candidate[:total_time_seconds] }, precision: 0),
        average_rating: rounded_average(sample.filter_map { |candidate| candidate[:rating] }, precision: 1)
      }
    end

    def score(candidate)
      ratio_penalty = (candidate[:ratio] - TARGET_RATIO).abs * 10
      time_penalty = time_distance(candidate[:total_time_seconds]) / 2.to_d
      rating_bonus = candidate[:rating].present? ? candidate[:rating].to_d / 25 : 0

      ratio_penalty + time_penalty - rating_bonus
    end

    def time_distance(seconds)
      return 0.to_d if TARGET_TIME_RANGE.cover?(seconds)

      if seconds < TARGET_TIME_RANGE.begin
        TARGET_TIME_RANGE.begin - seconds
      else
        seconds - TARGET_TIME_RANGE.end
      end.to_d
    end

    def rounded_average(values, precision:)
      return if values.empty?

      (values.sum(&:to_d) / values.size).round(precision)
    end
end
