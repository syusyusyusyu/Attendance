namespace :demo do
  desc "履修科目・出席・申請データを生成します"
  task seed: :environment do
    CurriculumSeeder.new.run
  end

  desc "履修科目・デモデータを削除します"
  task reset: :environment do
    CurriculumSeeder.new.reset
  end
end

class CurriculumSeeder
  STUDENT_COUNT = 18
  SEED_WEEKS = 2
  SEED_YEAR = 2025
  BASE_STUDENT_EMAIL = "student@example.com"
  BASE_STUDENT_ID = "S12345"
  BASE_STUDENT_NAME = "生徒"
  PASSWORD = "password"

  TEACHER_PROFILES = [
    { email: "teacher@example.com", name: "先生" },
    { email: "tanaka@example.com", name: "田中先生" },
    { email: "sato@example.com", name: "佐藤先生" },
    { email: "takahashi@example.com", name: "高橋先生" }
  ].freeze

  CLASS_CATALOG = [
    {
      name: "ビジネスアプリケーションⅠ",
      subject: "ビジネス基礎",
      semester: "前期",
      room: "2C教室",
      day_of_week: 1,
      period: 1,
      description: "レポート作成や表計算、プレゼン資料を効率的に作成する基礎力を身に付ける。"
    },
    {
      name: "ITリテラシー",
      subject: "IT基礎",
      semester: "前期",
      room: "3A教室",
      day_of_week: 2,
      period: 2,
      description: "ITの基本概念とセキュリティ、個人情報保護の重要性を理解する。"
    },
    {
      name: "コンピュータシステム",
      subject: "基礎理論",
      semester: "前期",
      room: "3B教室",
      day_of_week: 3,
      period: 3,
      description: "2進数やデータ表現、OSやネットワークなどの基礎を学ぶ。"
    },
    {
      name: "プログラミングⅠ",
      subject: "プログラミング",
      semester: "前期",
      room: "4A教室",
      day_of_week: 4,
      period: 4,
      description: "C#の文法と構造化プログラミング、デバッグの基礎を習得する。"
    },
    {
      name: "ビジネスアプリケーションⅡ",
      subject: "データベース基礎",
      semester: "後期",
      room: "2C教室",
      day_of_week: 1,
      period: 2,
      description: "Accessを使ったテーブル作成、リレーション設定、フォーム活用を学ぶ。"
    },
    {
      name: "プログラミングⅡ",
      subject: "プログラミング",
      semester: "後期",
      room: "4B教室",
      day_of_week: 2,
      period: 3,
      description: "設計書の理解やテスト仕様の作成を含む実践的な演習で基礎力を固める。"
    },
    {
      name: "PG実践Ⅰ",
      subject: "プログラミング演習",
      semester: "後期",
      room: "4C教室",
      day_of_week: 3,
      period: 4,
      description: "基礎技術とデータベースを反復訓練し、実践力を養成する。"
    },
    {
      name: "テスト技法",
      subject: "品質保証",
      semester: "後期",
      room: "4D教室",
      day_of_week: 4,
      period: 5,
      description: "テスト理論とテストコード作成をツール演習で身に付ける。"
    },
    {
      name: "コミュニケーション技法",
      subject: "ビジネス",
      semester: "後期",
      room: "6C教室",
      day_of_week: 1,
      period: 4,
      description: "自己紹介やグループ演習を通じて適切な意思伝達を学ぶ。"
    },
    {
      name: "ゼミナールⅠ",
      subject: "ゼミ",
      semester: "前期",
      room: "6D教室",
      day_of_week: 2,
      period: 5,
      description: "学習・生活スタイルの確立と自己管理能力の向上を目指す。"
    },
    {
      name: "システム設計Ⅰ",
      subject: "設計",
      semester: "前期",
      room: "5C教室",
      day_of_week: 3,
      period: 5,
      description: "要件定義から外部設計・内部設計までのタスクを学ぶ。"
    },
    {
      name: "SQLⅠ",
      subject: "データベース",
      semester: "前期",
      room: "5A教室",
      day_of_week: 1,
      period: 3,
      description: "SQLの基本操作や検索条件、関数、結合を理解する。"
    },
    {
      name: "SQLⅡ",
      subject: "データベース",
      semester: "後期",
      room: "5B教室",
      day_of_week: 2,
      period: 4,
      description: "データ操作や表作成など実践的なSQL活用を学ぶ。"
    },
    {
      name: "キャリアデザイン",
      subject: "キャリア",
      semester: "後期",
      room: "5D教室",
      day_of_week: 4,
      period: 1,
      description: "就職活動に向けた自己理解と選考対応力を養う。"
    },
    {
      name: "CMSサイト構築",
      subject: "Web",
      semester: "前期",
      room: "6A教室",
      day_of_week: 5,
      period: 2,
      description: "CMSの構築とカスタマイズ、PHP基礎を演習で学ぶ。"
    },
    {
      name: "モバイルアプリケーション開発",
      subject: "モバイル",
      semester: "前期",
      room: "6B教室",
      day_of_week: 5,
      period: 3,
      description: "Android開発環境の構築とGUI/DB/ネットワーク連携の基礎を学ぶ。"
    },
    {
      name: "インターンシップⅠ",
      subject: "キャリア",
      semester: "後期",
      room: "7B教室",
      day_of_week: 4,
      period: 2,
      description: "就業体験を通じて業界理解を深め、キャリア形成に役立てる。"
    },
    {
      name: "ITパスポート試験",
      subject: "資格対策",
      semester: "前期",
      room: "8A教室",
      day_of_week: 1,
      period: 5,
      description: "過去問題や模擬試験を通じて合格水準の知識を身に付ける。"
    },
    {
      name: "情報セキュリティマネジメント試験",
      subject: "資格対策",
      semester: "後期",
      room: "8B教室",
      day_of_week: 2,
      period: 1,
      description: "情報セキュリティの知識を演習で強化し合格水準を目指す。"
    }
  ].freeze

  def initialize
    @rng = Random.new(202501)
  end

  def run
    ActiveRecord::Base.transaction do
      teachers = seed_teachers
      students = seed_students
      classes = seed_classes(teachers)
      classes.each do |klass|
        enroll_students(klass, students)
        seed_attendance_for_class(klass, students)
      end
    end
  end

  def reset
    class_names = CLASS_CATALOG.map { |row| row[:name] }
    SchoolClass.where(name: class_names).find_each(&:destroy!)
    User.where(email: extra_teacher_emails).destroy_all
    User.where(email: extra_student_emails).destroy_all
  end

  private

  def seed_teachers
    TEACHER_PROFILES.map do |profile|
      User.find_or_initialize_by(email: profile[:email]).tap do |user|
        user.name = profile[:name]
        user.role = "teacher"
        user.password = PASSWORD
        user.password_confirmation = PASSWORD
        user.save!
      end
    end
  end

  def seed_students
    students = []
    base_student = User.find_or_initialize_by(email: BASE_STUDENT_EMAIL)
    base_student.assign_attributes(
      name: BASE_STUDENT_NAME,
      role: "student",
      student_id: BASE_STUDENT_ID,
      password: PASSWORD,
      password_confirmation: PASSWORD
    )
    base_student.save!
    students << base_student

    (1..STUDENT_COUNT).each do |index|
      email = format("student%02d@example.com", index)
      student = User.find_or_initialize_by(email: email)
      student.assign_attributes(
        name: format("学生%02d", index),
        role: "student",
        student_id: format("S2%03d", index),
        password: PASSWORD,
        password_confirmation: PASSWORD
      )
      student.save!
      students << student
    end

    students
  end

  def seed_classes(teachers)
    CLASS_CATALOG.map.with_index do |attrs, index|
      teacher = teachers[index % teachers.length]
      times = SchoolClass.period_times(attrs[:period])
      schedule = {
        day_of_week: attrs[:day_of_week],
        period: attrs[:period],
        start_time: times[:start],
        end_time: times[:end],
        frequency: "weekly"
      }

      SchoolClass.find_or_initialize_by(name: attrs[:name]).tap do |klass|
        klass.teacher = teacher
        klass.room = attrs[:room]
        klass.subject = attrs[:subject]
        klass.semester = attrs[:semester]
        klass.year = SEED_YEAR
        klass.capacity = 40
        klass.description = attrs[:description]
        klass.schedule = schedule
        klass.is_active = true
        klass.save!
        AttendancePolicy.find_or_create_by!(school_class: klass)
      end
    end
  end

  def enroll_students(klass, students)
    enrolled = students.sample([students.length, 18].min, random: @rng)
    enrolled << students.first unless enrolled.include?(students.first)
    enrolled.each do |student|
      Enrollment.find_or_create_by!(school_class: klass, student: student)
    end
  end

  def seed_attendance_for_class(klass, students)
    date_range = SEED_WEEKS.weeks.ago.to_date..Date.current
    date_range.each do |date|
      result = ClassSessionResolver.new(school_class: klass, date: date).resolve
      next unless result

      session = result[:session]
      next if session.status_canceled?

      enrolled_students = klass.students.to_a
      next if enrolled_students.empty?

      enrolled_students.each do |student|
        record = AttendanceRecord.find_or_initialize_by(
          user: student,
          school_class: klass,
          date: date
        )
        next if record.persisted?

        status = sample_status
        record.status = status
        record.verification_method = status == "absent" ? "system" : "qrcode"
        record.class_session = session
        record.timestamp = session.start_at || Time.zone.parse("#{date} 09:10")

        if status != "absent"
          check_in = session.start_at + @rng.rand(0..15).minutes
          check_in = session.start_at + 20.minutes if status == "late"
          record.checked_in_at = check_in
        end

        record.checked_out_at = session.start_at + 50.minutes if status == "early_leave"

        record.save!

        maybe_create_request(klass, student, record)
        maybe_create_manual_change(klass, record)
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

  def maybe_create_request(klass, student, record)
    return unless %w[absent late excused].include?(record.status)
    return unless @rng.rand < 0.2

    status = @rng.rand < 0.7 ? "approved" : "pending"
    teacher = klass.teacher
    request = AttendanceRequest.create!(
      user: student,
      school_class: klass,
      class_session: record.class_session,
      date: record.date,
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
      date: record.date,
      previous_status: previous_status,
      new_status: record.status,
      reason: request.reason,
      modified_by: teacher,
      source: "manual",
      changed_at: Time.current
    )
  end

  def maybe_create_manual_change(klass, record)
    return unless @rng.rand < 0.05

    previous_status = record.status
    new_status = %w[excused absent].sample(random: @rng)
    teacher = klass.teacher
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
      reason: "教員修正",
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

  def extra_teacher_emails
    TEACHER_PROFILES.map { |profile| profile[:email] } - ["teacher@example.com"]
  end

  def extra_student_emails
    (1..STUDENT_COUNT).map { |index| format("student%02d@example.com", index) }
  end
end
