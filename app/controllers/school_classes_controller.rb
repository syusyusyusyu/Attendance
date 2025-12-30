class SchoolClassesController < ApplicationController
  before_action -> { require_role!("teacher") }
  before_action :set_school_class, only: [:show, :edit, :update, :destroy, :roster_import]

  def index
    @classes = current_user.taught_classes.order(:name)
  end

  def show
    @enrollments = @school_class.enrollments.joins(:student).order("users.name")
    @overrides = @school_class.class_session_overrides.order(date: :desc)
    @override = @school_class.class_session_overrides.new
  end

  def new
    @school_class = current_user.taught_classes.new
  end

  def create
    @school_class = current_user.taught_classes.new(school_class_params)
    @school_class.schedule = schedule_params

    if @school_class.save
      AttendancePolicy.find_or_create_by!(school_class: @school_class, **AttendancePolicy.default_attributes)
      redirect_to school_class_path(@school_class), notice: "クラスを作成しました。"
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
      redirect_to school_class_path(@school_class), notice: "クラス情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @school_class.update!(is_active: false)
    redirect_to school_classes_path, notice: "クラスを無効化しました。"
  end

  def roster_import
    file = params[:csv_file]

    if file.blank?
      redirect_to school_class_path(@school_class), alert: "CSVファイルを選択してください。" and return
    end

    result = RosterCsvImporter.new(
      teacher: current_user,
      school_class: @school_class,
      csv_text: file.read
    ).import

    message = "インポート完了: 新規#{result[:created]}件 / 更新#{result[:updated]}件 / 履修追加#{result[:enrolled]}件"
    if result[:errors].any?
      errors = result[:errors].first(3).join(" ")
      redirect_to school_class_path(@school_class), alert: "#{message} (エラー: #{errors})"
    else
      redirect_to school_class_path(@school_class), notice: message
    end
  end

  private

  def set_school_class
    @school_class = current_user.taught_classes.find(params[:id])
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
    start_time = data[:schedule_start_time].presence
    end_time = data[:schedule_end_time].presence
    frequency = data[:schedule_frequency].presence || "weekly"

    return {} if day.blank? || start_time.blank? || end_time.blank?

    {
      "day_of_week" => day.to_i,
      "start_time" => start_time,
      "end_time" => end_time,
      "frequency" => frequency
    }
  end
end
