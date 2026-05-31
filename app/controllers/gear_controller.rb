class GearController < ApplicationController
  def index
    @equipment = current_workspace.equipment
      .includes(:primary_photo_record, photos_attachments: :blob)
      .order(Arel.sql("archived_at ASC NULLS FIRST"), :kind, :name)
    @preparation_tools = current_workspace.preparation_tools
      .includes(:primary_photo_record, photos_attachments: :blob)
      .ordered
  end
end
