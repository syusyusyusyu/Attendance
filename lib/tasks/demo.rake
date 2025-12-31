namespace :demo do
  desc "デモ用の授業回・出席・申請データを生成します"
  task seed: :environment do
    DemoSeeder.new.run
  end

  desc "デモデータを削除します"
  task reset: :environment do
    DemoSeeder.new.reset
  end
end

class DemoSeeder
  STUDENT_COUNT = 18
  DEMO_TEACHER_EMAIL = "demo_teacher@example.com"
  DEMO_PREFIX = "デモ"

  def initialize
    @rng = Random.new(202501)
  end

  def run
    ActiveRecord::Base.transaction do
      teacher = find_or_create_teacher
      students = find_or_create_students
      classes = find_or_create_classes(teacher)
      classes.each do |klass|
        enroll_students(klass, students)
        seed_attendance_for_class(klass, teacher, students)
      end
    end
  end

  def reset
    demo_classes = SchoolClass.where("name LIKE ?", "#{DEMO_PREFIX}%")
    demo_classes.find_each do |klass|
      klass.destroy!
    end
    User.where(email: DEMO_TEACHER_EMAIL).destroy_all
    User.where("email LIKE ?", "demo_student%@example.com").destroy_all
  end

  private

  def find_or_create_teacher
    User.find_or_create_by!(email: DEMO_TEACHER_EMAIL) do |user|
      user.name = "デモ教員"
      user.role = "teacher"
      user.password = "password"
      user.password_confirmation = "password"
    end
  end

  def find_or_create_students
    (1..STUDENT_COUNT).map do |index|
      email = "demo_student#{index}@example.com"
      User.find_or_create_by!(email: email) do |user|
        user.name = "デモ学生#{index}"
        user.role = "student"
        user.student_id = format("D%04d", index)
        user.password = "password"
        user.password_confirmation = "password"
      end
    end
  end

  def find_or_create_classes(teacher)
    [
      {
        name: "#{DEMO_PREFIX}Webアプリ開発",
        room: "A201",
        subject: "Web",
        semester: "前期",
        year: 2024,
        capacity: 40,
        schedule: { day_of_week: 1, start_time: "09:00", end_time: "10:30", frequency: "weekly" }
      },
      {
        name: "#{DEMO_PREFIX}ネットワーク演習",
        room: "B301",
        subject: "NW",
        semester: "前期",
        year: 2024,
        capacity: 40,
        schedule: { day_of_week: 3, start_time: "13:00", end_time: "14:30", frequency: "weekly" }
      }
    ].map do |attrs|
      SchoolClass.find_or_create_by!(name: attrs[:name], teacher: teacher) do |klass|
        klass.room = attrs[:room]
        klass.subject = attrs[:subject]
        klass.semester = attrs[:semester]
        klass.year = attrs[:year]
        klass.capacity = attrs[:capacity]
        klass.schedule = attrs[:schedule]
      end.tap do |klass|
        AttendancePolicy.find_or_create_by!(school_class: klass)
      end
    end
  end

  def enroll_students(klass, students)
    students.each do |student|
      Enrollment.find_or_create_by!(school_class: klass, student: student)
    end
  end

  def seed_attendance_for_class(klass, teacher, students)
    date_range = 4.weeks.ago.to_date..Date.current
    date_range.each do |date|
      result = ClassSessionResolver.new(school_class: klass, date: date).resolve
      next unless result

      session = result[:session]
      next if session.status_canceled?

      students.each do |student|
        record = AttendanceRecord.find_or_initialize_by(user: student, school_class: klass, date: date)
        next if record.persisted?

        status = sample_status
        record.status = status
        record.verification_method = status == "absent" ? "system" : "qrcode"
        record.class_session = session
        record.timestamp = session.start_at || Time.zone.parse("#{date} 09:00")

        if status != "absent"
          check_in = session.start_at + @rng.rand(0..15).minutes
          if status == "late"
            check_in = session.start_at + 20.minutes
          end
          record.checked_in_at = check_in
        end

        if status == "early_leave"
          record.checked_out_at = session.start_at + 50.minutes
        end

        record.save!

        maybe_create_request(klass, teacher, student, date, record)
        maybe_create_manual_change(klass, teacher, record)
      end
    end
  end

  def sample_status
    roll = @rng.rand
    return "present" if roll < 0.65
    return "late" if roll < 0.75
    return "early_leave" if roll < 0.83
    return "excused" if roll < 0.92

    "absent"
  end

  def maybe_create_request(klass, teacher, student, date, record)
    return unless %w[absent late excused].include?(record.status)
    return unless @rng.rand < 0.2

    status = @rng.rand < 0.7 ? "approved" : "pending"
    request = AttendanceRequest.create!(
      user: student,
      school_class: klass,
      class_session: record.class_session,
      date: date,
      request_type: record.status,
      reason: sample_reason(record.status),
      status: status,
      submitted_at: Time.current,
      processed_by: status == "approved" ? teacher : nil,
      processed_at: status == "approved" ? Time.current : nil
    )

    return unless request.status_approved?

    previous_status = record.status
    record.update!(
      status: request.request_type,
      verification_method: "manual",
      modified_by: teacher,
      modified_at: Time.current
    )

    AttendanceChange.create!(
      attendance_record: record,
      user: student,
      school_class: klass,
      date: date,
      previous_status: previous_status,
      new_status: record.status,
      reason: request.reason,
      modified_by: teacher,
      source: "manual",
      changed_at: Time.current
    )
  end

  def maybe_create_manual_change(klass, teacher, record)
    return unless @rng.rand < 0.05

    previous_status = record.status
    new_status = %w[excused absent].sample(random: @rng)
    record.update!(
      status: new_status,
      verification_method: "manual",
      modified_by: teacher,
      modified_at: Time.current
    )

    AttendanceChange.create!(
      attendance_record: record,
      user: record.user,
      school_class: klass,
      date: record.date,
      previous_status: previous_status,
      new_status: new_status,
      reason: "デモ修正",
      modified_by: teacher,
      source: "manual",
      changed_at: Time.current
    )
  end

  def sample_reason(status)
    case status
    when "absent"
      ["体調不良", "就職活動", "家庭都合"].sample(random: @rng)
    when "late"
      ["電車遅延", "寝坊", "体調不良"].sample(random: @rng)
    when "excused"
      ["公式イベント参加", "企業説明会"].sample(random: @rng)
    else
      "申請"
    end
  end
end
