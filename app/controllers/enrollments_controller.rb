class EnrollmentsController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }

  def create
    school_class = current_user.manageable_classes.find(params[:school_class_id])
    keyword = params[:keyword].to_s.strip

    if keyword.blank?
      redirect_to school_class_path(school_class), alert: "学生IDかメールアドレスを入力してください。" and return
    end

    student =
      User.where(role: "student").find_by(student_id: keyword) ||
      User.where(role: "student").find_by(email: keyword)

    unless student
      redirect_to school_class_path(school_class), alert: "学生が見つかりませんでした。" and return
    end

    Enrollment.find_or_create_by!(school_class: school_class, student: student)
    redirect_to school_class_path(school_class), notice: "履修登録を追加しました。"
  end

  def destroy
    school_class = current_user.manageable_classes.find(params[:school_class_id])
    enrollment = school_class.enrollments.find(params[:id])
    enrollment.destroy
    redirect_to school_class_path(school_class), notice: "履修登録を削除しました。"
  end
end
