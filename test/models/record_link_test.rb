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

  test "allows a 120-character multibyte label" do
    link = RecordLink.new(
      workspace: workspaces(:household),
      linkable: beans(:open_household),
      label: "ä" * 120,
      url: "https://example.com/coffee",
      kind: "info",
      visibility: "public",
      position: 10
    )

    assert_predicate link, :valid?
  end

  test "rejects a 121-character multibyte label" do
    link = RecordLink.new(
      workspace: workspaces(:household),
      linkable: beans(:open_household),
      label: "ä" * 121,
      url: "https://example.com/coffee",
      kind: "info",
      visibility: "public",
      position: 10
    )

    assert_not_predicate link, :valid?
    assert_includes link.errors[:label], "is too long (maximum is 120 characters)"
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

  test "blank nested record link row is ignored despite default select values" do
    bean = beans(:open_household)

    assert_no_difference -> { bean.record_links.count } do
      bean.update!(
        record_links_attributes: {
          "0" => {
            label: "",
            url: "",
            kind: "info",
            visibility: "private",
            position: "10",
            _destroy: "0"
          }
        }
      )
    end
  end

  test "nested record links can update and delete existing links" do
    bean = beans(:open_household)
    link = bean.record_links.create!(
      label: "Old label",
      url: "https://example.com/old",
      kind: "info",
      visibility: "private",
      position: 10
    )
    deleted_link = bean.record_links.create!(
      label: "Delete me",
      url: "https://example.com/delete",
      kind: "buy",
      visibility: "public",
      position: 20
    )

    bean.update!(
      record_links_attributes: {
        "0" => {
          id: link.id,
          label: "Updated label",
          url: "https://example.com/updated",
          kind: "affiliate",
          visibility: "public",
          position: "30"
        },
        "1" => {
          id: deleted_link.id,
          _destroy: "1"
        }
      }
    )

    assert_equal "Updated label", link.reload.label
    assert_equal "affiliate", link.kind
    assert_equal "public", link.visibility
    assert_equal 30, link.position
    assert_not RecordLink.exists?(deleted_link.id)
  end

  test "blank existing nested link without destroy remains invalid" do
    bean = beans(:open_household)
    link = bean.record_links.create!(
      label: "Keep me",
      url: "https://example.com/keep",
      kind: "info",
      visibility: "private",
      position: 10
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      bean.update!(
        record_links_attributes: {
          "0" => {
            id: link.id,
            label: "",
            url: "",
            kind: "info",
            visibility: "private",
            position: "10",
            _destroy: "0"
          }
        }
      )
    end

    assert_equal "Keep me", link.reload.label
  end
end
