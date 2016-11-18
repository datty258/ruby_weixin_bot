class Api::V1::UsersController < ApplicationController
  def show
    @user = User.find params[:id]
  end

  def update
    @user = User.find(params[:id])
    binding.pry
    return api_error(status: 403) if !UserPolicy.new(current_user, @user).update?
    @user.update_attributes(update_params)
  end
end
