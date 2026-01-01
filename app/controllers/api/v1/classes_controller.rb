class Api::V1::ClassesController < Api::BaseController
  def index
    return unless require_scope!("classes:read")

    classes = accessible_classes.order(:name)
    render json: classes.map { |klass| class_payload(klass) }
  end

  def show
    return unless require_scope!("classes:read")

    klass = accessible_classes.find(params[:id])
    render json: class_payload(klass)
  end

  def attendance_records
    return unless require_scope!("attendance:read")

    klass = accessible_classes.find(params[:id])
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_month
    end_date = start_date if end_date < start_date

    records = AttendanceRecord
              .includes(:user)
              .where(school_class: klass, date: start_date..end_date)
              .order(:date, :user_id)

    render json: {
      class: class_payload(klass),
      start_date: start_date,
      end_date: end_date,
      records: records.map do |record|
        {
          date: record.date,
          student_id: record.user.student_id,
          name: record.user.name,
          status: record.status,
          checked_in_at: record.checked_in_at,
          checked_out_at: record.checked_out_at,
          duration_minutes: record.duration_minutes
        }
      end
    }
  rescue ArgumentError
    render json: { error: "日付の形式が正しくありません。" }, status: :unprocessable_entity
  end

  def students
    return unless require_scope!("students:read")

    klass = accessible_classes.find(params[:id])
    render json: klass.students.order(:name).map { |student| student_payload(student) }
  end

  private

  def accessible_classes
    return SchoolClass.all if current_api_user&.admin?
    return current_api_user.manageable_classes if current_api_user&.staff?

    current_api_user.enrolled_classes
  end

  def class_payload(klass)
    {
      id: klass.id,
      name: klass.name,
      room: klass.room,
      subject: klass.subject,
      semester: klass.semester,
      year: klass.year,
      schedule: klass.schedule
    }
  end

  def student_payload(student)
    {
      id: student.id,
      student_id: student.student_id,
      name: student.name,
      email: student.email
    }
  end
end
