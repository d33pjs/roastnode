require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "buy me a coffee url is optional" do
    workspace = workspaces(:household)

    workspace.buy_me_a_coffee_url = ""

    assert workspace.valid?
  end

  test "buy me a coffee url accepts buymeacoffee https urls" do
    workspace = workspaces(:household)

    workspace.buy_me_a_coffee_url = " https://www.buymeacoffee.com/roastnode "

    assert workspace.valid?
    assert_equal "https://www.buymeacoffee.com/roastnode", workspace.buy_me_a_coffee_url
  end

  test "buy me a coffee url rejects non-buymeacoffee hosts and unsafe schemes" do
    workspace = workspaces(:household)

    workspace.buy_me_a_coffee_url = "https://example.test/roastnode"
    assert_not workspace.valid?

    workspace.buy_me_a_coffee_url = "javascript:alert(1)"
    assert_not workspace.valid?
  end
end
