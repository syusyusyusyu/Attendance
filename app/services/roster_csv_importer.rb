require "csv"

class RosterCsvImporter
  def initialize(teacher:, school_class:, csv_text:)
    @teacher = teacher
    @school_class = school_class
    @csv_text = csv_text
  end

  def import
    result = { created: 0, updated: 0, enrolled: 0, errors: [] }
    sanitized_csv = @csv_text.to_s.sub(/\A\uFEFF/, "")

    CSV.parse(sanitized_csv, headers: true).each_with_index do |row, index|
      line_no = index + 2
      student_id = row["学生ID"] || row["student_id"] || row["StudentID"]
      name = row["氏名"] || row["name"] || row["Name"]
      email = row["メール"] || row["email"] || row["Email"]
      password = row["パスワード"] || row["password"] || row["Password"]

      student_id = student_id.to_s.strip
      name = name.to_s.strip
      email = email.to_s.strip
      password = password.to_s.strip

      if student_id.blank? || name.blank? || email.blank?
        result[:errors] << "行#{line_no}: 学生ID/氏名/メールが必要です。"
        next
      end

      user = User.find_by(email: email) || User.find_by(student_id: student_id)

      if user.nil?
        user = User.new(
          email: email,
          name: name,
          role: "student",
          student_id: student_id,
          password: password.presence || student_id,
          password_confirmation: password.presence || student_id
        )
        if user.save
          result[:created] += 1
        else
          result[:errors] << "行#{line_no}: #{user.errors.full_messages.join("、")}"
          next
        end
      else
        if user.role != "student"
          result[:errors] << "行#{line_no}: 学生以外のアカウントです。"
          next
        end

        updates = {}
        updates[:name] = name if user.name != name
        updates[:student_id] = student_id if user.student_id != student_id
        updates[:email] = email if user.email != email

        if updates.any?
          unless user.update(updates)
            result[:errors] << "行#{line_no}: #{user.errors.full_messages.join("、")}"
            next
          end
          result[:updated] += 1
        end
      end

      existing = Enrollment.find_by(school_class: @school_class, student: user)
      if existing
        next
      end

      Enrollment.create!(school_class: @school_class, student: user)
      result[:enrolled] += 1
    end

    result
  end
end
