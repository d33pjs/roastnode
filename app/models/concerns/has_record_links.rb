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
    count.times { record_links.build(workspace:) }
  end
end
