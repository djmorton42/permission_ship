module Api
  module V1
    module Development
      # The demo logins from db/seeds/demo_data.rb, for the login page in development.
      # The route exists only in development and test. The action also checks the
      # environment, so the list is never sent from a deployed environment.
      class DemoAccountsController < BaseController
        def show
          return head :not_found unless Rails.env.local?

          # Loaded here, not at class load, so production never loads the seed file.
          require Rails.root.join("db/seeds/demo_data").to_s
          render json: { password: DemoData::DEMO_PASSWORD, boards: DemoData.directory }
        end
      end
    end
  end
end
