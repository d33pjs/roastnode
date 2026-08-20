class BeanComparisonRanker
  def initialize(bean:)
    @bean = bean
  end

  def call
    {
      "average_rating" => comparison_for(average_ratings, higher_is_better: true),
      "channeling" => comparison_for(channeling_percentages, higher_is_better: false)
    }.compact
  end

  private
    attr_reader :bean

    def average_ratings
      grouped_brews.filter_map do |bean_id, brews|
        ratings = brews.filter_map(&:rating)
        next if ratings.empty?

        [ bean_id, (ratings.sum.to_d / ratings.size).round(1) ]
      end.to_h
    end

    def channeling_percentages
      grouped_brews.filter_map do |bean_id, brews|
        espresso_brews = brews.select(&:espresso?)
        next if espresso_brews.empty?

        percentage = ((espresso_brews.count(&:channeling?).to_d / espresso_brews.size) * 100).round
        [ bean_id, percentage ]
      end.to_h
    end

    def grouped_brews
      @grouped_brews ||= workspace_brews.group_by(&:bean_id)
    end

    def workspace_brews
      @workspace_brews ||= Brew
        .where(workspace_id: bean.workspace_id)
        .select(:bean_id, :method, :rating, :channeling)
        .to_a
    end

    def comparison_for(values, higher_is_better:)
      current_value = values[bean.id]
      return if current_value.nil? || values.size < 2

      better_count = values.values.count do |value|
        higher_is_better ? value > current_value : value < current_value
      end

      { "rank" => better_count + 1, "eligible_count" => values.size }
    end
end
