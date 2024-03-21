# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  it "creates user successfully" do
    user = create(:user)
    expect(user).to be_valid
  end
end
