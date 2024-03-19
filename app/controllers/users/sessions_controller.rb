# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout "devise"

    def after_sign_in_path_for(_)
      dashboard_path
    end
  end
end
