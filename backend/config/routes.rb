# typed: strict

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Background job dashboard (Solid Queue)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :health, only: :show, controller: "health"
      resource :session, only: %i[show create destroy] do
        resource :organization, only: :create, controller: "session_organizations"
      end
      resources :school_administrators, only: %i[update destroy]
      resources :schools, only: [] do
        resources :invitations, only: :create
      end
      resources :invitations, only: :destroy do
        post :resend, on: :member
      end
      resources :invitation_acceptances, only: :create do
        post :preview, on: :collection
      end

      # Demo logins for the login page. Development and test only.
      if Rails.env.local?
        namespace :development do
          resource :demo_accounts, only: :show
        end
      end
    end
  end
end
