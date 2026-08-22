require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "recipient symbols use explicit paths instead of the more menu fallback" do
    fallback_path = ApplicationHelper::MATERIAL_SYMBOL_PATHS.fetch("more_vert")

    %w[person home groups].each do |name|
      path = ApplicationHelper::MATERIAL_SYMBOL_PATHS.fetch(name)

      assert_not_equal fallback_path, path
      assert_includes material_symbol(name), %(data-symbol="#{name}")
      assert_includes material_symbol(name), %(d="#{path}")
    end
  end
end
