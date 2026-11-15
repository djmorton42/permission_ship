Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Background job dashboard (Solid Queue)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :health, only: :show, controller: "health"
    end
  end
end
