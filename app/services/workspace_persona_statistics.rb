# Receives the already workspace-, date-, and people-filtered brews from
# WorkspaceStatistics. Identity keys stay internal; chart payloads contain only
# labels and aggregates, never serialized records or database identifiers.
class WorkspacePersonaStatistics
  def initialize(brews:)
    @brews = brews
  end

  def call
    {
      makers: maker_groups.map do |_id, records|
        self_count = records.count(&:recipient_self?)
        { label: user_label(records.first.user), count: records.size, self_count:, others_count: records.size - self_count }
      end,
      recipients: recipient_groups.map do |_identity, records|
        { label: recipient_label(records), count: records.size, bean_count: records.map(&:bean_id).uniq.size, **ratings(records) }
      end,
      servings:,
      recipient_beans:,
      favorites: recipient_beans.map do |recipient|
        {
          label: recipient[:label],
          beans: recipient[:beans].select { |bean| bean[:rated_count].positive? }
            .sort_by { |bean| [ -bean[:average_rating], -bean[:rated_count], bean[:label].downcase ] }
        }
      end,
      totals:
    }
  end

  private
    attr_reader :brews

    def maker_groups
      @maker_groups ||= brews.group_by(&:user_id).sort_by do |id, records|
        [ -records.size, user_label(records.first.user).downcase, id ]
      end
    end

    def recipient_groups
      @recipient_groups ||= brews.group_by { |brew| recipient_identity(brew) }.sort_by do |identity, records|
        [ -records.size, recipient_label(records).downcase, identity ]
      end
    end

    def recipient_identity(brew)
      if brew.recipient_guest?
        [ "guest", brew.recipient_name.to_s.strip.downcase(:fold) ]
      else
        [ "user", brew.recipient_self? ? brew.user_id : brew.recipient_user_id ]
      end
    end

    def recipient_label(records)
      brew = records.first
      return user_label(brew.recipient_self? ? brew.user : brew.recipient_user) unless brew.recipient_guest?

      # Choose a stable spelling within the selection, independent of row order.
      name = records.map { |record| record.recipient_name.to_s.strip }.min
      name.present? ? I18n.t("statistics.personas.named_guest", name:) : I18n.t("statistics.personas.unnamed_guests")
    end

    def user_label(user)
      user&.display_label || I18n.t("statistics.personas.unknown_person")
    end

    def servings
      counts = brews.map { |brew| [ brew.user_id, recipient_identity(brew) ] }.tally
      {
        labels: maker_groups.map { |_id, records| user_label(records.first.user) },
        datasets: recipient_groups.map do |identity, records|
          { label: recipient_label(records), data: maker_groups.map { |id, _records| counts.fetch([ id, identity ], 0) } }
        end
      }
    end

    def recipient_beans
      @recipient_beans ||= recipient_groups.map do |_identity, records|
        beans = records.group_by(&:bean_id).sort_by do |id, bean_brews|
          [ -bean_brews.size, bean_label(bean_brews.first.bean).downcase, id ]
        end.map do |_id, bean_brews|
          { label: bean_label(bean_brews.first.bean), count: bean_brews.size, **ratings(bean_brews) }
        end
        { label: recipient_label(records), count: records.size, beans: }
      end
    end

    def bean_label(bean)
      [ bean.name, bean.roaster_name.presence ].compact.join(" · ")
    end

    def ratings(records)
      values = records.filter_map(&:rating)
      { rated_count: values.size, average_rating: values.empty? ? nil : values.sum.to_f / values.size }
    end

    def totals
      self_served = brews.count(&:recipient_self?)
      {
        self_served:,
        served_to_others: brews.size - self_served,
        recipient_count: recipient_groups.size,
        rated_count: brews.count { |brew| brew.rating.present? }
      }
    end
end
