class HistoryPaginator
  DEFAULT_PER_PAGE = 20

  attr_reader :page, :per_page, :records

  def initialize(scope, page:, per_page: DEFAULT_PER_PAGE)
    @scope = scope
    @page = normalize_page(page)
    @per_page = per_page
    @records = load_records
  end

  def previous_page
    page - 1 if page > 1
  end

  def next_page
    page + 1 if @has_next_page
  end

  def any?
    records.any?
  end

  private
    attr_reader :scope

    def normalize_page(value)
      Integer(value)
    rescue ArgumentError, TypeError
      1
    else
      value.to_i.positive? ? value.to_i : 1
    end

    def load_records
      items = if relation_scope?
        scope.offset(offset).limit(per_page + 1).to_a
      else
        scope.to_a.slice(offset, per_page + 1) || []
      end

      @has_next_page = items.size > per_page
      items.first(per_page)
    end

    def relation_scope?
      scope.respond_to?(:offset) && scope.respond_to?(:limit)
    end

    def offset
      (page - 1) * per_page
    end
end
