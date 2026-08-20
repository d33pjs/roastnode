require "test_helper"

class BeanComparisonRankerTest < ActiveSupport::TestCase
  test "ranks rounded average rating higher first with competition ties" do
    workspace = create_workspace("Ranking")
    first = create_bean(workspace:, name: "First")
    tied = create_bean(workspace:, name: "Tied")
    third = create_bean(workspace:, name: "Third")

    create_brew(first, rating: 5, channeling: false)
    create_brew(tied, rating: 5, channeling: true)
    create_brew(third, rating: 4, channeling: false)

    assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(first, "average_rating"))
    assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(tied, "average_rating"))
    assert_equal({ "rank" => 3, "eligible_count" => 3 }, comparison(third, "average_rating"))
  end

  test "ties ratings at the displayed one decimal precision" do
    workspace = create_workspace("Rounded ranking")
    first = create_bean(workspace:, name: "Rounded first")
    second = create_bean(workspace:, name: "Rounded second")

    [ 4, 5 ].each { |rating| create_brew(first, rating:, channeling: false) }
    ([ 5 ] * 9 + [ 4 ] * 11).each { |rating| create_brew(second, rating:, channeling: false) }

    assert_equal "4.5", public_average(first)
    assert_equal "4.5", public_average(second)
    assert_equal({ "rank" => 1, "eligible_count" => 2 }, comparison(first, "average_rating"))
    assert_equal({ "rank" => 1, "eligible_count" => 2 }, comparison(second, "average_rating"))
  end

  test "omits rating comparison until two beans have rated brews" do
    bean = create_bean(workspace: create_workspace("Single ranking"), name: "Only rated")
    create_brew(bean, rating: 5, channeling: false)

    assert_nil BeanComparisonRanker.new(bean:).call["average_rating"]
  end

  test "ranks rounded channeling lower first with competition ties" do
    workspace = create_workspace("Channeling ranking")
    zero = create_bean(workspace:, name: "Zero")
    tied_zero = create_bean(workspace:, name: "Tied zero")
    channeled = create_bean(workspace:, name: "Channeled")

    create_brew(zero, rating: nil, channeling: false)
    create_brew(tied_zero, rating: nil, channeling: false)
    create_brew(channeled, rating: nil, channeling: true)

    assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(zero, "channeling"))
    assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(tied_zero, "channeling"))
    assert_equal({ "rank" => 3, "eligible_count" => 3 }, comparison(channeled, "channeling"))
  end

  test "excludes Quick Drip and other workspaces from channeling comparison" do
    workspace = create_workspace("Isolated ranking")
    current = create_bean(workspace:, name: "Current")
    peer = create_bean(workspace:, name: "Peer")
    quick_drip_only = create_bean(workspace:, name: "Quick Drip only")
    create_brew(current, rating: nil, channeling: true)
    create_brew(peer, rating: nil, channeling: false)
    create_brew(quick_drip_only, rating: 5, channeling: nil, method: "quick_drip")

    other_workspace = create_workspace("Other ranking")
    other = create_bean(workspace: other_workspace, name: "Other")
    create_brew(other, rating: 5, channeling: false)

    assert_equal({ "rank" => 2, "eligible_count" => 2 }, comparison(current, "channeling"))
    assert_nil BeanComparisonRanker.new(bean: quick_drip_only).call["channeling"]
  end

  private
    def create_workspace(name)
      Workspace.create!(name:, kind: "household", default_currency: "EUR")
    end

    def comparison(bean, metric)
      BeanComparisonRanker.new(bean:).call.fetch(metric)
    end

    def public_average(bean)
      ratings = bean.brews.where.not(rating: nil).pluck(:rating)
      (ratings.sum.to_d / ratings.size).round(1).to_s("F")
    end

    def create_bean(workspace:, name:)
      workspace.beans.create!(
        name:,
        roaster_name: "Comparison Roaster",
        bag_size_grams: 250,
        remaining_grams: 250,
        grind_state: "whole_bean",
        opened_on: Date.current
      )
    end

    def create_brew(bean, rating:, channeling:, method: "espresso")
      attributes = {
        user: users(:one),
        bean:,
        method:,
        bean_weight_grams: 1,
        rating:,
        channeling:
      }
      if method == "quick_drip"
        attributes[:brewer] = bean.workspace.equipment.create!(name: "Ranking Brewer", kind: "brewer")
        attributes[:machine_cups] = 1
      end

      bean.workspace.brews.create!(attributes)
    end
end
