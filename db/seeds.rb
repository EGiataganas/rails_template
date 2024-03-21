# frozen_string_literal: true

User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "secret_password"
  user.password_confirmation = "secret_password"
end
