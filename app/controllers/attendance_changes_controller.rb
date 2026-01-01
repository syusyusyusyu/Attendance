require "csv"

class AttendanceChangesController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("attendance.logs.view") }

  def index
    @classes = current_user.manageable_classes.order(:name)
    @saved_searches = current_user.audit_saved_searches.where(scope: "attendance_changes").order(:name)

    filter_params = {
      "class_id" => params[:class_id],
      "start_date" => params[:start_date],
      "end_date" => params[:end_date],
      "source" => params[:source],
      "status" => params[:status],
      "q" => params[:q]
    }

    if params[:saved_search_id].present?
      saved = @saved_searches.find_by(id: params[:saved_search_id])
      filter_params = filter_params.merge(saved&.filters || {})
    elsif filter_params.values.all?(&:blank?)
      default_search = @saved_searches.find_by(is_default: true)
      filter_params = filter_params.merge(default_search&.filters || {}) if default_search
    end

    @selected_class = @classes.find_by(id: filter_params["class_id"])
    @start_date = filter_params["start_date"].present? ? Date.parse(filter_params["start_date"]) : nil
    @end_date = filter_params["end_date"].present? ? Date.parse(filter_params["end_date"]) : nil
    @source = filter_params["source"].presence
    @status = filter_params["status"].presence
    @query = filter_params["q"].to_s.strip.presence

    scope = AttendanceChange
            .includes(:user, :school_class, :modified_by)
            .order(changed_at: :desc)
    scope = scope.where(school_class: @selected_class) if @selected_class
    if @start_date || @end_date
      from = @start_date || @end_date
      to = @end_date || @start_date
      scope = scope.where(changed_at: from.beginning_of_day..to.end_of_day)
    end
    scope = scope.where(source: @source) if @source
    scope = scope.where(new_status: @status) if @status

    if @query.present?
      scope = scope.left_joins(:user, :school_class)
                   .joins("LEFT JOIN users AS modified_users ON modified_users.id = attendance_changes.modified_by_id")
                   .where(
                     "users.name ILIKE :q OR users.student_id ILIKE :q OR attendance_changes.reason ILIKE :q "\
                     "OR modified_users.name ILIKE :q OR school_classes.name ILIKE :q",
                     q: "%#{@query}%"
                   )
    end

    @changes = scope.limit(200)

    if params[:save_search_name].present?
      save_search!(filter_params)
      redirect_to attendance_logs_path(filter_params.except("q").merge(q: filter_params["q"])) and return
    end

    respond_to do |format|
      format.html
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ["変更時刻", "クラス", "学籍ID", "氏名", "変更前", "変更後", "理由", "変更者", "種別", "IP", "UserAgent"]
          scope.limit(1000).each do |change|
            csv << [
              change.changed_at&.strftime("%Y-%m-%d %H:%M:%S"),
              change.school_class&.name,
              change.user&.student_id,
              change.user&.name,
              change.previous_status,
              change.new_status,
              change.reason,
              change.modified_by&.name,
              change.source,
              change.ip,
              change.user_agent
            ]
          end
        end
        send_data "\uFEFF#{csv_data}", filename: "attendance-changes.csv", type: "text/csv; charset=utf-8"
      end
    end
  rescue ArgumentError
    redirect_to attendance_logs_path, alert: "日付の形式が正しくありません。"
  end

  private

  def save_search!(filters)
    name = params[:save_search_name].to_s.strip
    return if name.blank?

    cleaned = filters.each_with_object({}) do |(key, value), memo|
      memo[key] = value if value.present?
    end

    AuditSavedSearch.transaction do
      if params[:save_search_default].to_s == "1"
        current_user.audit_saved_searches.where(scope: "attendance_changes").update_all(is_default: false)
      end

      saved = current_user.audit_saved_searches.find_or_initialize_by(scope: "attendance_changes", name: name)
      saved.filters = cleaned
      saved.is_default = params[:save_search_default].to_s == "1"
      saved.save!
    end
  end
end
