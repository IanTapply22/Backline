Backline::Engine.routes.draw do
  root to: "dashboard#index"
  get "dashboard/live", to: "dashboard#live", as: :live_dashboard

  resources :jobs, only: [ :index, :show ] do
    post :retry_job, on: :member
  end

  resources :queues, only: :index
  resources :workers, only: :index
  resources :recurring_tasks, only: :index
  resources :batches, only: [ :index, :show ]
  resources :workflows, only: [ :index, :show ]
  resource :metrics, only: :show
end
