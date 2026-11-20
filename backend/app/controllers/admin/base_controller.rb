# typed: strict

module Admin
  # Base for internal, server-rendered admin tools (e.g. Mission Control at /jobs).
  # Inherits ActionController::Base because the rest of the app is API-only
  # and can't render HTML views.
  class BaseController < ActionController::Base
  end
end
