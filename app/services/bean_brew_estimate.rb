class BeanBrewEstimate
  def self.for_bags(workspace:, beans:)
    averages = workspace.brews.where(bean_id: beans.map(&:id))
      .where("bean_weight_grams > 0").group(:bean_id).average(:bean_weight_grams)

    beans.to_h do |bean|
      average = averages[bean.id]
      [ bean.id, average && (bean.remaining_grams / average).floor ]
    end
  end
end
