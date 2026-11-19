module Api
  module V1
    class HealthController < BaseController
      # Public: uptime checks have no session. Whether it stays public is in todo.md.
      allow_without_session only: :show

      def show
        render json: {
          status: "ok",
          database: database_ok?,
          jobs: jobs_ok?,
          time: Time.current.iso8601
        }
      end

      private

      def database_ok?
        ActiveRecord::Base.connection.select_value("SELECT 1") == 1
      rescue StandardError
        false
      end

      # True when at least one Solid Queue process has checked in recently.
      def jobs_ok?
        SolidQueue::Process.where(last_heartbeat_at: SolidQueue.process_alive_threshold.ago..).exists?
      rescue StandardError
        false
      end
    end
  end
end
