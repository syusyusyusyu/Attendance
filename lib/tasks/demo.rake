require "pg"

namespace :demo do
  desc "デモデータを作成(同期/固定シード)"
  task seed: :environment do
    DemoDataSyncer.new.seed!
  end

  desc "デモデータを削除"
  task reset: :environment do
    DemoDataSyncer.new.reset!
  end

  desc "Render DBの内容をデモDBへ同期"
  task sync: :environment do
    DemoDataSyncer.new.sync_from_source!
  end
end

class DemoDataSyncer
  SOURCE_ENV_KEY = "DEMO_SOURCE_DATABASE_URL"
  EXCLUDED_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  def seed!
    if source_url?
      sync_from_source!
    else
      CurriculumSeeder.new.run
    end
  end

  def reset!
    connection = ActiveRecord::Base.connection
    truncate_tables!(connection, connection.tables - EXCLUDED_TABLES)
  end

  def sync_from_source!
    source_url = ENV[SOURCE_ENV_KEY].to_s.strip
    raise "#{SOURCE_ENV_KEY} is required" if source_url.empty?

    connection = ActiveRecord::Base.connection
    tables = sorted_tables(connection)

    truncate_tables!(connection, tables)
    copy_tables(source_url, connection.raw_connection, tables)
    reset_sequences!(connection, tables)
  end

  private

  def source_url?
    ENV[SOURCE_ENV_KEY].to_s.strip.length.positive?
  end

  def sorted_tables(connection)
    tables = connection.tables - EXCLUDED_TABLES
    graph = tables.to_h { |table| [table, []] }

    tables.each do |table|
      connection.foreign_keys(table).each do |foreign_key|
        to_table = foreign_key.to_table
        graph[table] << to_table if graph.key?(to_table)
      end
    end

    sorted = []
    temporary = {}
    permanent = {}

    visit = lambda do |table|
      return if permanent[table]
      raise "Circular dependency detected for #{table}" if temporary[table]

      temporary[table] = true
      graph[table].each { |dep| visit.call(dep) }
      permanent[table] = true
      sorted << table
    end

    tables.each { |table| visit.call(table) }
    sorted
  end

  def truncate_tables!(connection, tables)
    return if tables.empty?

    quoted = tables.map { |table| connection.quote_table_name(table) }.join(", ")
    connection.execute("TRUNCATE TABLE #{quoted} RESTART IDENTITY CASCADE")
  end

  def copy_tables(source_url, target_raw, tables)
    source = PG.connect(source_url)
    source.exec("SET statement_timeout = 0")
    target_raw.exec("SET statement_timeout = 0")

    tables.each do |table|
      quoted = PG::Connection.quote_ident(table)
      source.copy_data("COPY #{quoted} TO STDOUT WITH CSV") do
        target_raw.copy_data("COPY #{quoted} FROM STDIN WITH CSV") do
          while (row = source.get_copy_data)
            target_raw.put_copy_data(row)
          end
        end
      end
    end
  ensure
    source&.close
  end

  def reset_sequences!(connection, tables)
    tables.each { |table| connection.reset_pk_sequence!(table) }
  end
end

class CurriculumSeeder
  STUDENT_COUNT = 18
  SEED_WEEKS = 2
  SEED_YEAR = Time.zone.today.year
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
      description: "レポート作成、表計算、プレゼン資料の基礎を学ぶ。"
    },
    {
      name: "ITリテラシー",
      subject: "IT基礎",
      semester: "前期",
      room: "3A教室",
      day_of_week: 2,
      period: 2,
      description: "ITの基本概念とセキュリティ、情報モラルを理解する。"
    },
    {
      name: "コンピュータシステム",
      subject: "基礎理論",
      semester: "前期",
      room: "3B教室",
      day_of_week: 3,
      period: 3,
      description: "2進数/OS/ネットワークなどの基礎を学ぶ。"
    },
    {
      name: "プログラミングⅠ",
      subject: "プログラミング",
      semester: "前期",
      room: "4A教室",
      day_of_week: 4,
      period: 4,
      description: "C#の構文と構造化プログラミング、デバッグの基礎。"
    },
    {
      name: "ビジネスアプリケーションⅡ",
      subject: "データベース基礎",
      semester: "後期",
      room: "2C教室",
      day_of_week: 1,
      period: 2,
      description: "Accessでテーブル/リレーション/フォームの活用を学ぶ。"
    },
    {
      name: "プログラミングⅡ",
      subject: "プログラミング",
      semester: "後期",
      room: "4B教室",
      day_of_week: 2,
      period: 3,
      description: "設計書/テスト仕様を含む実践演習で基礎力を固める。"
    },
    {
      name: "PG実践Ⅰ",
      subject: "プログラミング演習",
      semester: "後期",
      room: "4C教室",
      day_of_week: 3,
      period: 4,
      description: "基礎技術を反復し、実装力を養う。"
    },
    {
      name: "テスト技法",
      subject: "品質保証",
      semester: "後期",
      room: "4D教室",
      day_of_week: 4,
      period: 5,
      description: "テスト理論とテストコード作成を演習で学ぶ。"
    },
    {
      name: "コミュニケーション技法",
      subject: "ビジネス",
      semester: "後期",
      room: "6C教室",
      day_of_week: 1,
      period: 4,
      description: "自己紹介やグループ演習で伝達力を高める。"
    },
    {
      name: "ゼミナールⅠ",
      subject: "ゼミ",
      semester: "前期",
      room: "6D教室",
      day_of_week: 2,
      period: 5,
      description: "学習/生活スタイルの確立と自己管理力の向上。"
    },
    {
      name: "システム設計Ⅰ",
      subject: "設計",
      semester: "前期",
      room: "5C教室",
      day_of_week: 3,
      period: 5,
      description: "要件定義から外部/内部設計までの流れを学ぶ。"
    },
    {
      name: "SQLⅠ",
      subject: "データベース",
      semester: "前期",
      room: "5A教室",
      day_of_week: 1,
      period: 3,
      description: "SQLの基本操作や検索条件、結合を理解する。"
    },
    {
      name: "SQLⅡ",
      subject: "データベース",
      semester: "後期",
      room: "5B教室",
      day_of_week: 2,
      period: 4,
      description: "実践的なSQLとテーブル設計の応用を学ぶ。"
    },
    {
      name: "キャリアデザイン",
      subject: "キャリア",
      semester: "後期",
      room: "5D教室",
      day_of_week: 4,
      period: 1,
      description: "就職活動に向けた自己分析と選考準備を行う。"
    },
    {
      name: "CMSサイト構築",
      subject: "Web",
      semester: "前期",
      room: "6A教室",
      day_of_week: 5,
      period: 2,
      description: "CMSの構築とカスタマイズ、基礎的なWeb開発。"
    },
    {
      name: "モバイルアプリケーション開発",
      subject: "モバイル",
      semester: "前期",
      room: "6B教室",
      day_of_week: 5,
      period: 3,
      description: "Android開発の環境構築とGUI/DB/連携の基礎。"
    },
    {
      name: "インターンシップⅠ",
      subject: "キャリア",
      semester: "後期",
      room: "7B教室",
      day_of_week: 4,
      period: 2,
      description: "就業体験を通じて業界理解と職業観を深める。"
    },
    {
      name: "ITパスポート試験",
      subject: "資格対策",
      semester: "前期",
      room: "8A教室",
      day_of_week: 1,
      period: 5,
      description: "過去問題演習で合格水準の知識を身に付ける。"
    },
    {
      name: "情報セキュリティマネジメント試験",
      subject: "資格対策",
      semester: "後期",
      room: "8B教室",
      day_of_week: 2,
      period: 1,
      description: "情報セキュリティ分野の知識を強化する。"
    },
    {
      name: "クラウド基盤演習",
      subject: "クラウド",
      semester: "後期",
      room: "9D-1教室",
      day_of_week: 3,
      period: 2,
      description: "クラウド基盤の設計と運用を実践で学ぶ。"
    },
    {
      name: "AIシステム開発",
      subject: "AI",
      semester: "後期",
      room: "9D-2教室",
      day_of_week: 4,
      period: 3,
      description: "機械学習の基礎と業務適用を学ぶ。"
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
        seed_attendance_for_class(klass)
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

        AttendancePolicy.find_or_initialize_by(school_class: klass).tap do |policy|
          if policy.new_record?
            policy.assign_attributes(AttendancePolicy.default_attributes)
          end
          policy.save!
        end
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

  def seed_attendance_for_class(klass)
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
