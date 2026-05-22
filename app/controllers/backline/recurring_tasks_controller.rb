class Backline::RecurringTasksController < Backline::ApplicationController
  def index
    @tasks = Backline::DashboardSnapshot.recurring_task_entries
  end
end
