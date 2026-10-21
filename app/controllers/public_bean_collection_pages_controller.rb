class PublicBeanCollectionPagesController < ApplicationController
  allow_unauthenticated_access

  def show
    @collection = PublicBeanCollection.find_enabled_by_token!(params[:token])
    @snapshot = @collection.public_snapshot
    @view = params[:view] == "all" ? "all" : "top"
    all = Array(@snapshot["groups"])
    @total_groups = all.size
    @groups = @view == "all" ? all : all.select { |group| group["rank"] && group["rank"] <= 10 }
    @site_footer_buy_me_a_coffee = @collection.workspace.site_footer_buy_me_a_coffee
    @site_footer_show_version = false
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
