module HasRecordLinks
  extend ActiveSupport::Concern

  included do
    has_many :record_links, as: :linkable, dependent: :destroy
    accepts_nested_attributes_for :record_links, allow_destroy: true, reject_if: :all_blank
  end

  def build_blank_record_links(count = 3)
    count.times { record_links.build(workspace:) }
  end
end
