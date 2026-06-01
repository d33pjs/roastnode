require "test_helper"

class RecordLinkTest < ActiveSupport::TestCase
  test "requires http or https url" do
    link = RecordLink.new(
      workspace: workspaces(:household),
      linkable: beans(:open_household),
      label: "Bad",
      url: "javascript:alert(1)",
      kind: "affiliate",
      visibility: "public"
    )

    assert_not link.valid?
    assert_includes link.errors[:url], "must be an HTTP or HTTPS URL"
  end

  test "requires linkable to belong to the same workspace" do
    link = RecordLink.new(
      workspace: workspaces(:household),
      linkable: beans(:other_workspace_open),
      label: "Other",
      url: "https://example.com/other",
      kind: "info",
      visibility: "public"
    )

    assert_not link.valid?
    assert_includes link.errors[:linkable], "must belong to the workspace"
  end

  test "requires linkable to be a shareable record type" do
    link = RecordLink.new(
      workspace: workspaces(:household),
      linkable: workspaces(:household),
      label: "Workspace",
      url: "https://example.com/workspace",
      kind: "info",
      visibility: "public"
    )

    assert_not link.valid?
    assert_includes link.errors[:linkable_type], "is not a shareable record"
  end

  test "publicly_visible returns only public links in position order" do
    bean = beans(:open_household)
    private_link = bean.record_links.create!(
      workspace: bean.workspace,
      label: "Private receipt",
      url: "https://example.com/private",
      kind: "info",
      visibility: "private",
      position: 1
    )
    public_second = bean.record_links.create!(
      workspace: bean.workspace,
      label: "Buy",
      url: "https://example.com/buy",
      kind: "affiliate",
      visibility: "public",
      position: 20
    )
    public_first = bean.record_links.create!(
      workspace: bean.workspace,
      label: "Roaster",
      url: "https://example.com/roaster",
      kind: "info",
      visibility: "public",
      position: 10
    )

    assert_equal [ public_first, public_second ], bean.record_links.publicly_visible.to_a
    assert_not_includes bean.record_links.publicly_visible, private_link
  end
end
