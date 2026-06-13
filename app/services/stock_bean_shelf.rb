class StockBeanShelf
  Entry = Struct.new(:bean, keyword_init: true)

  def initialize(workspace:, limit: 5)
    @workspace = workspace
    @limit = limit
  end

  def call
    stock_beans.map { |bean| Entry.new(bean:) }
  end

  private
    attr_reader :workspace, :limit

    def stock_beans
      workspace.beans
        .where(archived_at: nil, finished_at: nil, opened_on: nil)
        .where("remaining_grams > 0")
        .includes(:primary_photo_record, photos_attachments: :blob)
        .order(
          Arel.sql("purchased_on DESC NULLS LAST"),
          Arel.sql("roast_date DESC NULLS LAST"),
          created_at: :desc,
          name: :asc
        )
        .limit(limit)
        .to_a
    end
end
