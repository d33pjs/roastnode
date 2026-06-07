class OpenBeanCockpit
  Entry = Struct.new(:bean, :latest_brew, :best_brew, :brew_count, :today, keyword_init: true) do
    def days_open
      days_since(bean.opened_on)
    end

    def days_since_roast
      days_since(bean.roast_date)
    end

    def remaining_state
      return "low" if bean.nearly_finished?
      return "medium" if bean.remaining_percent <= 45

      "plenty"
    end

    private
      def days_since(date)
        return if date.blank?

        [ (today - date.to_date).to_i, 0 ].max
      end
  end

  def initialize(workspace:, limit: 5, today: Date.current)
    @workspace = workspace
    @limit = limit
    @today = today
  end

  def call
    beans = open_beans
    brews_by_bean = brews_for(beans).group_by(&:bean_id)

    beans.map do |bean|
      brews = brews_by_bean.fetch(bean.id, [])
      Entry.new(
        bean:,
        latest_brew: brews.first,
        best_brew: best_brew_from(brews),
        brew_count: brews.size,
        today:
      )
    end
  end

  private
    attr_reader :workspace, :limit, :today

    def open_beans
      workspace.beans
        .open
        .left_joins(:brews)
        .includes(:primary_photo_record, photos_attachments: :blob)
        .select("beans.*, MAX(brews.occurred_at) AS latest_brew_at")
        .group("beans.id")
        .reorder(
          Arel.sql("MAX(brews.occurred_at) DESC NULLS LAST"),
          Arel.sql("beans.opened_on DESC NULLS LAST"),
          Arel.sql("beans.created_at DESC"),
          Arel.sql("LOWER(beans.name) ASC")
        )
        .limit(limit)
        .to_a
    end

    def brews_for(beans)
      return [] if beans.empty?

      workspace.brews
        .where(bean_id: beans.map(&:id))
        .includes(:grinder, :machine, :recipe)
        .order(occurred_at: :desc, created_at: :desc)
        .to_a
    end

    def best_brew_from(brews)
      brews
        .select { |brew| brew.rating.present? }
        .max_by { |brew| [ brew.rating, brew.occurred_at || Time.zone.at(0), brew.created_at || Time.zone.at(0) ] }
    end
end
