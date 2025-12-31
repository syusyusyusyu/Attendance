学校の出席管理システム 仕様書

## 1. 概要
本システムは、教員と学生が出席情報を管理するためのWebアプリケーションである。
Rails 8 + Hotwire + PostgreSQL 構成で実装し、Render.com にデプロイする。

## 2. 目的
- 授業単位での出席状況を簡単に記録、参照できること
- 学生がQRトークン入力で迅速に出席登録できること
- 教員が出席修正、確認を行えること

## 3. 対象ユーザーと権限
- 教員: 出席確認、QRコード生成、出席修正
- 学生: QRスキャン(トークン入力)、出席履歴の確認
- 管理者: 教員機能の全権 + 出席確定解除/強制修正の実行

## 4. 画面仕様
### 4.1 ログイン
- URL: /login
- 入力: email, password
- 成功時: ダッシュボードへ遷移
- 失敗時: エラーメッセージ表示

### 4.2 ダッシュボード
- URL: /
- 教員:
  - 出席確認ページへの導線
  - QRコード生成ページへの導線
  - 担当クラス一覧
- 学生:
  - QRスキャンページへの導線
  - 出席履歴ページへの導線
  - 履修クラス一覧

### 4.3 QRコード生成(教員)
- URL: /generate-qr
- クラス選択
- 5分有効のトークン生成
- QRコード表示
- 有効期限表示
- 自動ローテーションで一定間隔ごとに更新

### 4.4 QRスキャン(学生)
- URL: /scan
- 入力: QRトークン
- 成功時: 出席登録
- 失敗時: エラーメッセージ
- 2回目のスキャンで退室(チェックアウト)を記録

### 4.5 出席履歴(学生)
- URL: /history
- 日付選択
- 日付ごとの出席記録一覧

### 4.6 出席確認/修正(教員)
- URL: /attendance
- クラス選択、日付選択
- 学生一覧と出席ステータス編集
- 更新処理
- 授業回の出席確定/解除

### 4.7 QRスキャンログ(教員)
- URL: /scan-logs
- クラス/日付/結果/出席判定でフィルタ
- スキャン結果/出席判定/IP/端末情報を確認

### 4.8 出席ポリシー設定(教員)
- URL: /attendance 内
- 遅刻判定(分)/締切(分)/開始前許可を設定

### 4.9 CSVインポート(教員)
- URL: /attendance
- CSVから出席状況を一括反映

### 4.10 プロフィール
- URL: /profile
- 入力: 氏名、メール、学籍番号(学生のみ)、パスワード
- 更新後: 完了メッセージ

### 4.11 クラス管理(教員)
- URL: /school_classes
- クラス作成/編集/無効化
- 名簿CSVインポート/履修追加・削除
- 特別日程(休講/補講)を登録

### 4.12 出席変更ログ(教員)
- URL: /attendance-logs
- 変更理由・変更者・種別(手動/CSV/自動)を確認

### 4.13 レポート(教員)
- URL: /reports
- 期間指定でクラス別・学生別の出席傾向を集計

### 4.14 通知
- URL: /notifications
- 出席更新/休講/遅刻などの通知を一覧表示

### 4.15 出席申請
- URL: /attendance_requests
- 学生: 欠席/遅刻/公欠の申請、理由入力
- 教員: 申請の承認/却下、コメント入力

## 5. 機能仕様
### 5.1 認証
- セッションベース
- has_secure_password(bcrypt)
- emailは小文字に正規化

### 5.2 QRトークン
- RailsのMessageVerifierで署名
- payload: class_id, teacher_id, session_id, date, exp
- TTL: 5分
- 期限切れ、改ざんは無効

### 5.3 出席登録
- 同一日付は上書き
- status: present, late, absent, excused, early_leave
- verification_method: qrcode, manual, gps, beacon, system
- 登録時にtimestamp/checked_in_at を付与
- 退室スキャンでchecked_out_at/duration_minutesを更新
- 出席ポリシー(遅刻/締切/開始前許可/最低出席率)で自動判定

### 5.4 出席修正
- 教員/管理者
- modified_by, modified_at を記録
- 修正理由は必須

### 5.5 出席ポリシー
- クラスごとに遅刻判定/締切/開始前許可/最低出席率を設定
- 警告欠席回数/警告出席率を設定
- スキャン時にポリシーを参照して status を決定

### 5.6 名簿CSVインポート
- 学生ID/氏名/メールで学生を作成・更新し履修登録

### 5.7 特別日程(休講/補講)
- 日付単位でスケジュールを上書き
- 休講時はQRスキャンを無効化

### 5.8 変更ログ/通知
- 手動/CSV/QRスキャンによる変更を記録
- 学生へ通知を送信

### 5.9 出席申請
- 学生が欠席/遅刻/公欠の申請を送信
- 教員が承認/却下を行い、承認時は出席記録に反映
- 申請/処理は通知で共有

### 5.10 授業回/出席確定
- 授業回(ClassSession)を日付単位で生成
- 締切経過後に欠席を自動確定して授業回をロック
- 教員は授業回の確定が可能（解除は管理者のみ）

## 6. データモデル
### users
- id (PK)
- email (unique, not null)
- name (not null)
- role (student, teacher, admin)
- student_id (unique, nullable)
- profile_image (nullable)
- settings (jsonb)
- password_digest (not null)
- last_login

### school_classes
- id (PK)
- name
- teacher_id (FK -> users)
- room
- subject
- semester
- year
- capacity
- description
- schedule (jsonb)
- is_active

### enrollments
- id (PK)
- school_class_id (FK -> school_classes)
- student_id (FK -> users)
- enrolled_at
- unique(school_class_id, student_id)

### attendance_records
- id (PK)
- user_id (FK -> users)
- school_class_id (FK -> school_classes)
- class_session_id (FK -> class_sessions)
- date
- status
- timestamp
- checked_in_at
- checked_out_at
- duration_minutes
- location (jsonb)
- verification_method
- modified_by_id (FK -> users)
- modified_at
- notes
- unique(user_id, school_class_id, date)

### attendance_requests
- id (PK)
- user_id (FK -> users)
- school_class_id (FK -> school_classes)
- class_session_id (FK -> class_sessions)
- date
- request_type (absent/late/excused)
- status (pending/approved/rejected)
- reason
- submitted_at
- processed_by_id (FK -> users)
- processed_at
- decision_reason

### class_sessions
- id (PK)
- school_class_id (FK -> school_classes)
- date
- start_at
- end_at
- status (regular/makeup/canceled)
- locked_at
- note

### class_session_overrides
- id (PK)
- school_class_id (FK -> school_classes)
- date
- start_time
- end_time
- status (regular/makeup/canceled)
- note

### attendance_changes
- id (PK)
- attendance_record_id (FK -> attendance_records)
- user_id (FK -> users)
- school_class_id (FK -> school_classes)
- date
- previous_status
- new_status
- reason
- modified_by_id (FK -> users)
- source (manual/csv/system)
- ip
- user_agent
- changed_at

### notifications
- id (PK)
- user_id (FK -> users)
- kind (info/warning/success)
- title
- body
- action_path
- read_at

### qr_sessions
- id (PK)
- school_class_id (FK -> school_classes)
- teacher_id (FK -> users)
- attendance_date
- issued_at
- expires_at
- revoked_at

### qr_scan_events
- id (PK)
- qr_session_id (FK -> qr_sessions)
- user_id (FK -> users)
- school_class_id (FK -> school_classes)
- status
- attendance_status
- token_digest
- ip
- user_agent
- scanned_at

### attendance_policies
- id (PK)
- school_class_id (FK -> school_classes)
- late_after_minutes
- close_after_minutes
- allow_early_checkin
- allowed_ip_ranges
- allowed_user_agent_keywords
- max_scans_per_minute
- minimum_attendance_rate
- warning_absent_count
- warning_rate_percent

## 7. バリデーション
- User: email, name, role 必須
- User: email unique, student_id unique
- SchoolClass: name, room, subject, semester, year, capacity 必須
- Enrollment: unique(school_class_id, student_id)
- AttendanceRecord: date, status, verification_method 必須
- AttendanceChange: date, new_status, reason, changed_at 必須

## 8. 権限制御
- 教員/管理者: /attendance, /generate-qr, /reports, /scan-logs, /attendance-logs, /school_classes
- 学生のみ: /scan, /history
- 教員/管理者/学生: /attendance_requests
- 全員: /profile, /

## 9. 非機能要件
- 日本語UI
- タイムゾーン: Asia/Tokyo
- PostgreSQL永続化
- HTTPS強制(Render)

## 10. 環境変数
- DATABASE_URL
- RAILS_MASTER_KEY
- APP_HOST
- RAILS_ENV
- RAILS_SERVE_STATIC_FILES

## 11. デプロイ手順(Render)
- Build Command: bin/render-build.sh
- Start Command: bundle exec puma -C config/puma.rb
- DBはRenderのPostgreSQLを使用

## 12. 運用と監視
- ログ: STDOUT
- /up でヘルスチェック
- 障害時はRenderのログを確認

## 13. 既知の制約と今後の拡張
- QR読み取りはカメラ(BarcodeDetector + jsQRフォールバック)と手入力を併用
- 管理者専用画面は未実装（教員画面へのフルアクセスで運用）

## 14. 追加仕様: QR本格導入
- QR生成時に `QrSession` を作成し、`attendance_date`/`issued_at`/`expires_at` を保存
- トークンは `{class_id, teacher_id, session_id, date, exp}` を署名
- スキャン時は `QrSession` の期限/失効/日付を検証し、`QrScanEvent` にログを保存
- 同一トークンの重複スキャンは「すでに出席済み」として扱う
- QRコードは自動ローテーションで更新
- 2回目のスキャンで退室(チェックアウト)を記録
- 教員ダッシュボードに本日の出席サマリー(出席率/内訳)を表示
- 出席管理画面からCSVエクスポートを提供
- 環境変数 `QR_TOKEN_SECRET` を本番で必須化(変更で既存トークン無効)

## 15. 追加: カメラ対応ブラウザ/CSV
- QRカメラスキャンはChromium系ブラウザ(Chrome/Edge/Brave/Opera/Samsung Internet)を推奨、iOS Safari 16+ はjsQRフォールバックで対応
- iOS Safari 16+ は対応端末では利用可能
- 非対応端末は手入力フォールバック
- CSVは期間指定(`start_date`/`end_date`)に対応
- CSV項目に授業回ID/入室時刻/退室時刻/滞在分/申請状況/申請種別/申請理由を追加

## 16. 追加: 出席ポリシー/監査ログ/CSVインポート
- 出席ポリシーで遅刻判定/締切/開始前許可/最低出席率/警告閾値を設定
- QRスキャンログを `/scan-logs` で確認可能
- CSVインポートで出席状況を一括反映

## 17. 追加: クラス管理/通知/リアルタイム
- クラス作成・名簿インポート・履修追加/削除を提供
- 休講/補講の特別日程を登録できる
- 出席変更ログ `/attendance-logs` を提供
- レポート `/reports` で集計を可視化
- 通知 `/notifications` を提供
- QRスキャンで出席管理画面がリアルタイム更新
- 出席申請の申請/承認フローを提供
- 授業回の出席確定/解除と自動欠席確定を提供

## 18. 追加: レポート/分析
- クラス別の週次/日次出席率推移を提供
- 警告欠席回数/警告出席率に基づく要注意者の抽出
- 遅刻/早退理由の分布を可視化
- 期末レポート(PDF/CSV)を出力

## 19. 追加: 不正対策/権限
- QRローテーション + IP/端末制限 + 分間スキャン上限の運用
- 不正検知アラート(失敗多発/同一IP集中/QR共有)を通知
- 管理者のみ出席確定解除/強制修正を許可
