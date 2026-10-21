class BeanGroupLinksController < ApplicationController
  before_action :authorize_workspace_write!

  def update
    bean = current_workspace.beans.find(params[:bean_id])
    target_id = params.require(:bean_group_link).permit(:target_bean_id)[:target_bean_id]
    target = target_id == "separate" ? nil : current_workspace.beans.find(target_id)
    with_workspace_activity(action: "bean.updated", subject: bean) do
      bean.update!(coffee_history: target ? target.coffee_history : current_workspace.coffee_histories.create!)
      PublicBrewShareRefresher.refresh_for(bean)
      PublicBeanShareRefresher.refresh_for(bean)
      true
    end
    redirect_to bean, notice: t("bean_collection_operations.linked")
  end
end
