# frozen_string_literal: true

module ApplicationHelper
  MSG_CLASSES = { notice: :success, error: :danger }.freeze

  def msg_class(type)
    MSG_CLASSES[type.to_sym] || :info
  end
end
