module HasRecordLinks
  extend ActiveSupport::Concern

  REJECT_BLANK_RECORD_LINK_ATTRIBUTES = lambda do |attributes|
    value = ->(key) { attributes[key] || attributes[key.to_s] }

    value.call(:id).blank? &&
      !ActiveModel::Type::Boolean.new.cast(value.call(:_destroy)) &&
      value.call(:label).blank? &&
      value.call(:url).blank?
  end

  included do
    has_many :record_links, as: :linkable, dependent: :destroy
    accepts_nested_attributes_for :record_links, allow_destroy: true, reject_if: REJECT_BLANK_RECORD_LINK_ATTRIBUTES
  end

  def build_blank_record_links(count = 3)
    next_position = next_record_link_position
    count.times do |index|
      record_links.build(workspace:, position: next_position + (index * 10))
    end
  end

  def prepare_record_links_for_form(blank_rows: 1)
    build_blank_record_links(blank_rows)
  end

  private
    def next_record_link_position
      record_links.reject(&:marked_for_destruction?).filter_map(&:position).max.to_i + 10
    end
end
