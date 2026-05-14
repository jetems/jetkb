class Cards::AssignmentsController < ApplicationController
  include CardScoped

  def new
    @assigned_to = @card.assignees.active.alphabetically.where.not(id: Current.user)
    @users = @board.users.active.alphabetically.where.not(id: @card.assignees).where.not(id: Current.user)
    fresh_when etag: [ @users, @card.assignees ]
  end

  def create
    assignee_scope = request.format.json? ? @board.users.api_active : @board.users.active
    if @card.toggle_assignment assignee_scope.find(params[:assignee_id])
      respond_to do |format|
        format.turbo_stream
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.json { head :unprocessable_entity }
      end
    end
  end
end
