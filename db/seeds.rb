# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
teacher = User.find_or_initialize_by(email: "teacher@example.com")
teacher.assign_attributes(
  name: "鈴木一郎",
  role: "teacher",
  password: "password",
  password_confirmation: "password"
)
teacher.save!

student = User.find_or_initialize_by(email: "student@example.com")
student.assign_attributes(
  name: "山田太郎",
  role: "student",
  student_id: "S12345",
  password: "password",
  password_confirmation: "password"
)
student.save!

roles = {
  "admin" => { label: "管理者", description: "全権限を持つ管理者" },
  "teacher" => { label: "教員", description: "クラス運用と出席管理を担う教員" },
  "student" => { label: "学生", description: "出席登録と申請を行う学生" }
}

roles.each do |name, attrs|
  Role.find_or_create_by!(name: name) do |role|
    role.label = attrs[:label]
    role.description = attrs[:description]
  end
end

permissions = [
  { key: "admin.dashboard", label: "管理ダッシュボード閲覧" },
  { key: "admin.users.manage", label: "ユーザー管理" },
  { key: "admin.roles.manage", label: "権限管理" },
  { key: "admin.audit.view", label: "監査ログ閲覧" },
  { key: "admin.operation.approve", label: "承認ワークフロー処理" },
  { key: "attendance.manage", label: "出席管理(閲覧/修正)" },
  { key: "attendance.import", label: "CSVインポート" },
  { key: "attendance.policy.manage", label: "出席ポリシー設定" },
  { key: "attendance.finalize", label: "出席確定" },
  { key: "attendance.unlock", label: "出席確定解除" },
  { key: "attendance.request.approve", label: "出席申請の承認" },
  { key: "attendance.request.create", label: "出席申請の作成" },
  { key: "attendance.request.view", label: "出席申請の閲覧" },
  { key: "qr.generate", label: "QR発行" },
  { key: "qr.scan", label: "QRスキャン" },
  { key: "reports.view", label: "レポート閲覧" },
  { key: "reports.export", label: "レポート出力" },
  { key: "classes.manage", label: "クラス管理" },
  { key: "enrollments.manage", label: "履修管理" },
  { key: "session.override.manage", label: "休講/補講管理" },
  { key: "notifications.view", label: "通知閲覧" },
  { key: "profile.manage", label: "プロフィール更新" },
  { key: "history.view", label: "出席履歴閲覧" },
  { key: "history.export", label: "出席履歴出力" },
  { key: "scan.logs.view", label: "スキャンログ閲覧" },
  { key: "attendance.logs.view", label: "出席変更ログ閲覧" }
]

permissions.each do |attrs|
  Permission.find_or_create_by!(key: attrs[:key]) do |permission|
    permission.label = attrs[:label]
  end
end

role_permissions = {
  "admin" => permissions.map { |item| item[:key] },
  "teacher" => %w[
    attendance.manage
    attendance.import
    attendance.policy.manage
    attendance.finalize
    attendance.request.approve
    qr.generate
    reports.view
    reports.export
    classes.manage
    enrollments.manage
    session.override.manage
    notifications.view
    profile.manage
    scan.logs.view
    attendance.logs.view
  ],
  "student" => %w[
    qr.scan
    attendance.request.create
    attendance.request.view
    history.view
    history.export
    notifications.view
    profile.manage
  ]
}

role_permissions.each do |role_name, keys|
  role = Role.find_by!(name: role_name)
  keys.each do |key|
    permission = Permission.find_by!(key: key)
    RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end

admin = User.find_or_initialize_by(email: "admin@example.com")
admin.assign_attributes(
  name: "システム管理者",
  role: "admin",
  password: "password",
  password_confirmation: "password"
)
admin.save!
