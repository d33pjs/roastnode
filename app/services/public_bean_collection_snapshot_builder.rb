require "openssl"

class PublicBeanCollectionSnapshotBuilder
  BEAN_FIELDS = %w[name roaster_name origin process roast_type roast_level tasting_notes public_note decaffeinated links].freeze

  def initialize(collection:)
    @collection = collection
  end

  def call
    groups = shares.group_by { |share| share.bean.coffee_history_id }.map do |history_id, members|
      group_payload(history_id, members)
    end
    {
      "title" => collection.title,
      "description" => collection.description,
      "workspace" => { "name" => collection.workspace.name },
      "generated_at" => Time.current.iso8601,
      "groups" => rank_groups(groups)
    }
  end

  private
    attr_reader :collection

    def shares
      @shares ||= collection.included_shares.includes(:bean).order(:created_at, :id).to_a
    end

    def group_payload(history_id, members)
      representative = members.find { |share| collection.representative_share_ids.include?(share.id) } || members.first
      bags = members.map { |share| bag_payload(share) }.sort_by { |bag| [ bag["opened_on"].to_s, bag["share_token"] ] }
      brews = members.flat_map { |share| Array(share.snapshot["brews"]) }
      ratings = brews.filter_map { |brew| valid_rating(brew["rating"]) }
      {
        "key" => OpenSSL::HMAC.hexdigest("SHA256", collection.token, history_id.to_s).first(24),
        "bean" => representative.snapshot.fetch("bean", {}).slice(*BEAN_FIELDS),
        "bean_rating" => average(bags.filter_map { |bag| valid_rating(bag["bean_rating"]) }),
        "brew_average" => average(ratings),
        "rated_brew_count" => ratings.size,
        "brew_count" => brews.size,
        "bag_count" => bags.size,
        "total_grams" => bags.sum { |bag| bag["bag_size_grams"].to_d }.to_s("F"),
        "photos" => photo_payloads(representative),
        "bags" => bags,
        "public_brews" => public_brews(brews)
      }
    end

    def bag_payload(share)
      snapshot = share.snapshot
      bean = snapshot.fetch("bean", {})
      brews = Array(snapshot["brews"])
      ratings = brews.filter_map { |brew| valid_rating(brew["rating"]) }
      {
        "share_token" => share.token,
        "share_title" => snapshot["title"],
        "bag_size_grams" => bean["bag_size_grams"],
        "opened_on" => bean["opened_on"],
        "roast_date" => bean["roast_date"],
        "public_status" => bean["public_status"],
        "bean_rating" => bean["rating"],
        "brew_average" => average(ratings),
        "brew_count" => brews.size,
        "rated_brew_count" => ratings.size,
        "public_price" => bean["public_price"],
        "photos" => photo_payloads(share)
      }
    end

    def photo_payloads(share)
      Array(share.snapshot["photos"]).filter_map do |photo|
        handle = share.public_media_handle_for(photo["attachment_id"])
        next unless handle

        routes = Rails.application.routes.url_helpers
        { "thumbnail_url" => routes.public_bean_media_path(share.token, handle, variant: :thumbnail),
          "url" => routes.public_bean_media_path(share.token, handle) }
      end
    end

    def public_brews(brews)
      candidates = brews.select { |brew| brew["public_share"].is_a?(Hash) }
      @allowed_brew_tokens ||= collection.workspace.public_brew_shares.where(enabled: true, password_digest: nil).pluck(:token).to_set
      allowed = @allowed_brew_tokens
      candidates.filter_map do |brew|
        reference = brew["public_share"]
        next unless allowed.include?(reference["token"])

        reference.slice("token", "title").merge("rating" => brew["rating"], "method" => brew["method"])
      end.uniq { |brew| brew["token"] }.sort_by { |brew| [ -brew["rating"].to_f, brew["title"].to_s ] }
    end

    def valid_rating(value)
      number = BigDecimal(value.to_s, exception: false)
      number if number && number.between?(1, 5)
    end

    def average(values)
      return if values.empty?

      format("%.1f", (values.sum / values.size).round(1))
    end

    def rank_groups(groups)
      ordered = groups.sort_by do |group|
        [ -group["bean_rating"].to_f, -group["brew_average"].to_f, -group["rated_brew_count"],
          group.dig("bean", "roaster_name").to_s.downcase, group.dig("bean", "name").to_s.downcase, group["key"] ]
      end
      previous = nil
      rank = nil
      ordered.each_with_index do |group, index|
        if group["bean_rating"]
          scores = group.values_at("bean_rating", "brew_average", "rated_brew_count")
          rank = index + 1 unless scores == previous
          previous = scores
          group["rank"] = rank
        else
          group["rank"] = nil
        end
      end
      ordered
    end
end
