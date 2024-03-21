# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "abc@gmail.com" }
    password { "secret_pass" }
  end
end
