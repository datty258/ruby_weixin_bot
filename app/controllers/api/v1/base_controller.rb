class Api::V1::BaseController < ApplicationController
  # disable the CSRF token
  include Pundit
  protect_from_forgery with: :null_session
  attr_accessor :current_user
  # disable cookies (no set-cookies header in response)
  before_action :destroy_session

  # disable the CSRF token
  skip_before_action :verify_authenticity_token

  def destroy_session
    request.session_options[:skip] = true
  end

  def api_error(opts = {})
    render nothing: true, status: opts[:status]
  end
end
