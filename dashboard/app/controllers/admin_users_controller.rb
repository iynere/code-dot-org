require 'digest/md5'

require 'cdo/activity_constants'

class AdminUsersController < ApplicationController
  include Pd::PageHelper
  before_action :authenticate_user!
  before_action :require_admin

  DEFAULT_MANAGE_PAGE_SIZE = 25
  # restrict the PII returned by the controller to the view by selecting only these columns from the model
  RESTRICTED_USER_ATTRIBUTES_FOR_VIEW = %w(
    users.id
    email
    name
    user_type
    current_sign_in_at
    sign_in_count
    users.created_at
  ).freeze

  def account_repair_form
  end

  def account_repair
    return unless params[:email]
    hashed_email = Digest::MD5.hexdigest(params[:email])
    teacher = User.where(user_type: User::TYPE_TEACHER).
      where(hashed_email: hashed_email).
      where(email: '').
      first

    if teacher
      teacher.update!(email: params[:email])
      flash[:alert] = 'User fixed.'
    else
      flash[:alert] = 'Malformed teacher not found.'
    end

    render :account_repair_form
  end

  def assume_identity_form
  end

  def assume_identity
    user = User.where(id: params[:user_id]).first if params[:user_id].to_i.to_s == params[:user_id]
    user ||= User.where(username: params[:user_id]).first
    user ||= User.find_by_email_or_hashed_email(params[:user_id])

    if user
      bypass_sign_in user
      redirect_to '/'
    else
      flash[:alert] = 'User not found'
      render :assume_identity_form
    end
  end

  def undelete_user
    user = User.only_deleted.find_by_id(params[:user_id])
    if user
      user.restore(recursive: true, recovery_window: 5.minutes)
      flash[:alert] = "User (ID: #{params[:user_id]}) Undeleted!"
    else
      flash[:alert] = "User (ID: #{params[:user_id]}) not found or undeleted"
    end
    redirect_to :find_students
  end

  def manual_pass_form
  end

  def manual_pass
    user = User.find_by_id(params[:user_id])
    unless user
      flash[:alert] = "User (ID: #{params[:user_id]}) not found"
    end
    script = nil
    if params[:script_id_or_name].to_i.to_s == params[:script_id_or_name]
      script = Script.find_by_id(params[:script_id_or_name])
    else
      script = Script.find_by_name(params[:script_id_or_name])
    end
    unless script
      flash[:alert] = "Script (ID or Name: #{params[:script_id_or_name]}) not found"
    end
    level = Level.find_by_id(params[:level_id])
    unless level
      flash[:alert] = "Level (ID: #{params[:level_id]}) not found"
    end

    unless user && script && level
      redirect_to :manual_pass_form
      return
    end

    user_level = UserLevel.find_or_initialize_by(
      user: user,
      script: script,
      level: level
    )
    if user_level.persisted? &&
      user_level.best_result > ActivityConstants::MAXIMUM_NONOPTIMAL_RESULT
      flash[:alert] = "UserLevel (ID: #{user_level.id}) already green"
      redirect_to :manual_pass_form
      return
    end

    user_level.best_result = ActivityConstants::MANUAL_PASS_RESULT
    user_level.save!

    flash[:alert] = "UserLevel (ID: #{user_level.id}) updated"
    redirect_to :manual_pass_form
  end

  # get /admin/permissions
  def permissions_form
    search_term = params[:search_term]
    permission = params[:permission]
    if search_term.present?
      if search_term =~ /^\d+$/
        @user = restricted_users.find_by(id: search_term)
      else
        users = restricted_users.where(hashed_email: User.hash_email(search_term))
        @user = users.first
        if users.many?
          flash[:notice] = "More than one User matches email address.  "\
                         "Showing first result.  Matching User IDs - #{users.pluck(:id).join ','}"
        end
      end
      unless @user || search_term.blank?
        flash[:notice] = "User Not Found"
      end
    elsif permission.present?
      @users_with_permission = restricted_users.
                                 joins(:permissions).
                                 where(user_permissions: {permission: permission}).
                                 order(:email)
      @users_with_permission = @users_with_permission.page(page).per(page_size)
    end
  end

  def grant_permission
    user_id = params[:user_id]
    @user = restricted_users.find_by(id: user_id)
    unless @user.try(:teacher?)
      flash[:alert] = "FAILED: user #{user_id} could not be found or is not a teacher"
      redirect_to action: "permissions_form", search_term: user_id
      return
    end
    @user.permission = params[:permission]
    redirect_to permissions_form_path(search_term: user_id)
  end

  def revoke_permission
    user_id = params[:user_id]
    @user = restricted_users.find_by(id: user_id)
    permission = params[:permission]
    @user.try(:delete_permission, permission)
    redirect_to permissions_form_path(search_term: user_id)
  end

  private

  def restricted_users
    User.select(RESTRICTED_USER_ATTRIBUTES_FOR_VIEW)
  end

  def page
    params[:page] || 1
  end

  def page_size
    return DEFAULT_MANAGE_PAGE_SIZE unless params.key? :page_size
    params[:page_size] == 'All' ? @users_with_permission.count : params[:page_size]
  end
end
