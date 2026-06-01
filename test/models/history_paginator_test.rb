require "test_helper"

class HistoryPaginatorTest < ActiveSupport::TestCase
  test "normalizes invalid pages to page one" do
    paginator = HistoryPaginator.new([ 1, 2, 3 ], page: "bad", per_page: 2)

    assert_equal 1, paginator.page
    assert_equal [ 1, 2 ], paginator.records
    assert_nil paginator.previous_page
    assert_equal 2, paginator.next_page
  end

  test "paginates arrays with previous and next state" do
    paginator = HistoryPaginator.new([ 1, 2, 3, 4, 5 ], page: 2, per_page: 2)

    assert_equal 2, paginator.page
    assert_equal [ 3, 4 ], paginator.records
    assert_equal 1, paginator.previous_page
    assert_equal 3, paginator.next_page
  end

  test "paginates active record relations without loading unrelated pages" do
    workspace = workspaces(:household)
    relation = workspace.brews.order(occurred_at: :desc, created_at: :desc)

    paginator = HistoryPaginator.new(relation, page: 1, per_page: 1)

    assert_equal [ brews(:morning_espresso) ], paginator.records
    assert_nil paginator.previous_page
    assert_nil paginator.next_page
  end
end
