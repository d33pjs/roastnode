class BeanOpenDuration
  def initialize(bean:, latest_brew_at: nil, today: Date.current)
    @bean = bean
    @latest_brew_at = latest_brew_at
    @today = today.to_date
  end

  def call
    return if bean.opened_on.blank? || bean.stock?

    [ (end_date - bean.opened_on).to_i, 0 ].max
  end

  private
    attr_reader :bean, :latest_brew_at, :today

    def end_date
      case bean.bag_status
      when "finished"
        bean.finished_at.to_date
      when "archived"
        bean.archived_at.to_date
      when "used_up"
        latest_brew_at&.to_date || today
      else
        today
      end
    end
end
