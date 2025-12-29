class QrScansController < ApplicationController
  before_action -> { require_role!("student") }

  def new
  end

  def create
    result = AttendanceToken.verify(params[:token].to_s)

    unless result[:ok]
      redirect_to scan_path, alert: result[:error] and return
    end

    school_class = current_user.enrolled_classes.find_by(id: result[:class_id])
    unless school_class
      redirect_to scan_path, alert: "この授業に履修登録されていません。" and return
    end

    record = AttendanceRecord.find_or_initialize_by(
      user: current_user,
      school_class: school_class,
      date: Date.current
    )

    record.status = "present"
    record.verification_method = "qrcode"
    record.timestamp = Time.current

    if record.save
      redirect_to scan_path, notice: "出席を記録しました。"
    else
      redirect_to scan_path, alert: "出席記録に失敗しました。"
    end
  end
end
