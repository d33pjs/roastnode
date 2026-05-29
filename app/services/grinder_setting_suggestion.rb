class GrinderSettingSuggestion
  ParsedSetting = Struct.new(:raw, :format, :coordinate, keyword_init: true)

  TARGET_RATIO = BigDecimal("2.5")
  TARGET_TIME_RANGE = 25..30
  DIAL_TURNS_SIZE = BigDecimal("20")
  DEFAULT_DIAL_STEP = BigDecimal("0.25")
  DEFAULT_NUMERIC_STEP = BigDecimal("1")
  SECONDS_PER_ADJUSTMENT_STEP = BigDecimal("4")
  MAX_ADJUSTMENT_STEPS = 4
  MINIMUM_COMPARABLE_BREWS = 2

  def self.parse_setting(value)
    raw = value.to_s.strip
    return if raw.blank?

    if (match = raw.match(/\A(?<turn>-?\d+)\s*\/\s*(?<dial>-?\d+(?:[,.]\d+)?)\z/))
      turn = BigDecimal(match[:turn])
      dial = decimal(match[:dial])
      return ParsedSetting.new(raw:, format: :dial_turns, coordinate: (turn * DIAL_TURNS_SIZE) + dial)
    end

    if raw.match?(/\A-?\d+(?:[,.]\d+)?\z/)
      ParsedSetting.new(raw:, format: :plain_numeric, coordinate: decimal(raw))
    end
  end

  def initialize(bean:, minimum_comparable_brews: MINIMUM_COMPARABLE_BREWS)
    @bean = bean
    @minimum_comparable_brews = minimum_comparable_brews
  end

  def call
    calibration = calibration_candidate
    return [] unless calibration

    candidates = history_candidates(calibration)
    return [] if candidates.size < minimum_comparable_brews

    [ build_suggestion(calibration, candidates) ]
  end

  private
    attr_reader :bean, :minimum_comparable_brews

    def self.decimal(value)
      BigDecimal(value.to_s.tr(",", "."))
    end

    def calibration_candidate
      brew = bean.brews.includes(:grinder).order(:occurred_at, :created_at).first
      candidate_for(brew)
    end

    def history_candidates(calibration)
      brew_scope(calibration[:brew]).filter_map do |brew|
        candidate = candidate_for(brew)
        next unless candidate
        next unless candidate[:parsed_setting].format == calibration[:parsed_setting].format

        candidate
      end
    end

    def candidate_for(brew)
      return unless brew
      return unless brew.grinder&.grinder?
      return if brew.dose_grams.blank? || brew.dose_grams.to_d.zero?
      return if brew.beverage_grams.blank? || brew.total_time_seconds.blank?

      parsed_setting = self.class.parse_setting(brew.grind_setting)
      return unless parsed_setting

      {
        brew:,
        grinder: brew.grinder,
        parsed_setting:,
        ratio: brew.beverage_grams.to_d / brew.dose_grams.to_d,
        total_time_seconds: brew.total_time_seconds,
        rating: brew.rating
      }
    end

    def brew_scope(calibration_brew)
      bean.workspace.brews
        .includes(:grinder)
        .where(grinder: calibration_brew.grinder)
        .where.not(bean_id: bean.id)
    end

    def build_suggestion(calibration, candidates)
      {
        grinder: calibration[:grinder],
        calibration_brew: calibration[:brew],
        calibration_setting: calibration[:parsed_setting].raw,
        suggested_setting: suggested_setting(calibration, candidates),
        setting_format: calibration[:parsed_setting].format,
        time_status: time_status(calibration[:total_time_seconds]),
        comparable_brew_count: candidates.size,
        calibration_ratio: calibration[:ratio].round(2),
        calibration_total_time_seconds: calibration[:total_time_seconds],
        average_rating: rounded_average(candidates.filter_map { |candidate| candidate[:rating] }, precision: 1)
      }
    end

    def suggested_setting(calibration, candidates)
      return calibration[:parsed_setting].raw if time_status(calibration[:total_time_seconds]) == :on_target

      coordinate = adjusted_coordinate(calibration, candidates)
      format_setting(calibration[:parsed_setting], coordinate)
    end

    def adjusted_coordinate(calibration, candidates)
      status = time_status(calibration[:total_time_seconds])
      return calibration[:parsed_setting].coordinate if status == :on_target

      direction = status == :too_slow ? 1 : -1
      step_size = detected_step_size(calibration, candidates)
      adjustment = step_size * adjustment_steps(calibration[:total_time_seconds])

      [ calibration[:parsed_setting].coordinate + (direction * adjustment), 0.to_d ].max
    end

    def time_status(seconds)
      return :too_fast if seconds < TARGET_TIME_RANGE.begin
      return :too_slow if seconds > TARGET_TIME_RANGE.end

      :on_target
    end

    def adjustment_steps(seconds)
      seconds_off = if seconds > TARGET_TIME_RANGE.end
        seconds - TARGET_TIME_RANGE.end
      elsif seconds < TARGET_TIME_RANGE.begin
        TARGET_TIME_RANGE.begin - seconds
      else
        0
      end

      (seconds_off.to_d / SECONDS_PER_ADJUSTMENT_STEP).ceil.clamp(1, MAX_ADJUSTMENT_STEPS)
    end

    def detected_step_size(calibration, candidates)
      coordinates = ([ calibration ] + candidates).map { |candidate| candidate[:parsed_setting].coordinate }.uniq.sort
      detected_step = coordinates.each_cons(2).map { |left, right| right - left }.select(&:positive?).min
      default_step = default_step_size(calibration[:parsed_setting].format)

      [ detected_step || default_step, default_step ].min
    end

    def default_step_size(format)
      format == :dial_turns ? DEFAULT_DIAL_STEP : DEFAULT_NUMERIC_STEP
    end

    def format_setting(parsed_setting, coordinate)
      case parsed_setting.format
      when :dial_turns
        turn = (coordinate / DIAL_TURNS_SIZE).floor
        dial = coordinate - (turn * DIAL_TURNS_SIZE)

        "#{turn}/#{format_decimal(dial, separator_for(parsed_setting.raw), minimum_decimal: true)}"
      else
        format_decimal(coordinate, separator_for(parsed_setting.raw), minimum_decimal: parsed_setting.raw.match?(/[,.]/))
      end
    end

    def separator_for(raw)
      raw.include?(",") ? "," : "."
    end

    def format_decimal(value, separator, minimum_decimal:)
      decimal = format("%.2f", value.round(2).to_f)
      decimal = decimal.sub(/0+\z/, "").sub(/\.\z/, minimum_decimal ? ".0" : "")
      separator == "," ? decimal.tr(".", ",") : decimal
    end

    def rounded_average(values, precision:)
      return if values.empty?

      (values.sum(&:to_d) / values.size).round(precision)
    end
end
