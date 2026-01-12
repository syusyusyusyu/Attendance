class SchoolClassesController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("classes.manage") }
  before_action -> { require_permission!("enrollments.manage") }, only: [:roster_import]
  before_action -> { require_role!("admin") }, only: [:destroy]
  before_action :set_school_class, only: [:show, :edit, :update, :destroy, :roster_import]

  def index
    @classes = current_user.manageable_classes.order(:name)
  end

  def show
    @enrollments = @school_class.enrollments.joins(:student).order("users.name")
    @overrides = @school_class.class_session_overrides.order(date: :desc)
    @override = @school_class.class_session_overrides.new
  end

  def new
    @school_class =
      if current_user.teacher?
        current_user.taught_classes.new
      else
        SchoolClass.new(teacher: current_user)
      end
  end

  def create
    @school_class =
      if current_user.teacher?
        current_user.taught_classes.new(school_class_params)
      else
        SchoolClass.new(school_class_params.merge(teacher: current_user))
      end
    @school_class.schedule = schedule_params

    if @school_class.save
      AttendancePolicy.find_or_create_by!(school_class: @school_class, **AttendancePolicy.default_attributes)
      roster_result = import_roster_if_needed
      flash_type = roster_result&.fetch(:type, :notice) || :notice
      flash_message = "クラスを作成しました。"
      flash_message = "#{flash_message} #{roster_result[:message]}" if roster_result
      respond_to do |format|
        format.turbo_stream { flash.now[flash_type] = flash_message }
        format.html { redirect_to school_class_path(@school_class), flash_type => flash_message }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @school_class.assign_attributes(school_class_params)
    @school_class.schedule = schedule_params

    if @school_class.save
      roster_result = import_roster_if_needed
      if turbo_frame_request?
        render partial: "school_classes/card", locals: { klass: @school_class }
      else
        flash_type = roster_result&.fetch(:type, :notice) || :notice
        flash_message = "クラス情報を更新しました。"
        flash_message = "#{flash_message} #{roster_result[:message]}" if roster_result
        redirect_to school_class_path(@school_class), flash_type => flash_message
      end
    else
      if turbo_frame_request?
        render partial: "school_classes/inline_form", locals: { school_class: @school_class }, status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @school_class.destroy!
    redirect_to school_classes_path, notice: "クラスを削除しました。"
  end

  def roster_import
    file = params[:csv_file]

    if file.blank?
      redirect_to school_class_path(@school_class), alert: "CSVファイルを選択してください。" and return
    end

    roster_result = build_roster_import_result(file)
    redirect_to school_class_path(@school_class), roster_result[:type] => roster_result[:message]
  end

  private

  def set_school_class
    @school_class = current_user.manageable_classes.find(params[:id])
  end

  def school_class_params
    params.require(:school_class).permit(
      :name,
      :room,
      :subject,
      :semester,
      :year,
      :capacity,
      :description,
      :is_active
    )
  end

  def schedule_params
    data = params.fetch(:school_class, {})
    day = data[:schedule_day_of_week].presence
    period = data[:schedule_period].presence
    start_time = data[:schedule_start_time].presence
    end_time = data[:schedule_end_time].presence
    frequency = data[:schedule_frequency].presence || "weekly"
    use_custom_time = data[:schedule_use_custom_time].to_s == "1"

    if use_custom_time
      return {} if day.blank? || start_time.blank? || end_time.blank?

      return {
        "day_of_week" => day.to_i,
        "start_time" => start_time,
        "end_time" => end_time,
        "frequency" => frequency
      }
    end

    if period.present?
      times = SchoolClass.period_times(period)
      return {} if day.blank? || times.blank?

      return {
        "day_of_week" => day.to_i,
        "start_time" => times[:start],
        "end_time" => times[:end],
        "frequency" => frequency,
        "period" => period.to_i
      }
    end

    return {} if day.blank? || start_time.blank? || end_time.blank?

    {
      "day_of_week" => day.to_i,
      "start_time" => start_time,
      "end_time" => end_time,
      "frequency" => frequency
    }
  end

  def import_roster_if_needed
    file = params[:roster_csv_file]
    return nil if file.blank?

    build_roster_import_result(file)
  end

  def build_roster_import_result(file)
    result = RosterCsvImporter.new(
      teacher: current_user,
      school_class: @school_class,
      csv_text: file.read
    ).import

    message = "CSVインポート完了: 新規#{result[:created]}件 / 更新#{result[:updated]}件 / 履修追加#{result[:enrolled]}件"
    if result[:errors].any?
      errors = result[:errors].first(3).join(" ")
      return { type: :alert, message: "#{message} (エラー: #{errors})" }
    end

    { type: :notice, message: message }
  end
end
