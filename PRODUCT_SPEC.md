# 学校の出席管理システム 仕様書(要約版)

## 1. 概要
- Rails 8 + Hotwire + PostgreSQLで構築した出席管理Webアプリ
- 教員・学生・管理者の3ロール運用
- QR入室/退室、申請承認、監査ログ、レポートを一体化

## 2. 目的
- 出席記録の手入力を削減し、正確性と監査性を高める
- 学生の自己管理(履歴/申請/通知)を促進する
- 教員の運用(修正/確定/報告)を短時間で完結させる

## 3. ロールと権限
- 管理者: 全権限 + 承認ワークフローの最終実行
- 教員: クラス運用/出席管理/レポート閲覧
- 学生: QRスキャン/履歴/申請
- 権限制御: ロール/権限テーブルによる機能単位の認可

## 4. 主要画面
- `/login`: ログイン
- `/`: ダッシュボード
- `/generate-qr`: QR発行(教員)
- `/scan`: QRスキャン(学生)
- `/attendance`: 出席確認/修正/確定/CSV
- `/attendance_requests`: 出席申請/承認
- `/attendance-logs`: 出席変更ログ
- `/scan-logs`: スキャンログ
- `/reports`: 集計/期末レポート
- `/notifications`: 通知
- `/school_classes`: クラス/名簿/特別日程
- `/profile`: プロフィール/端末/通知設定
- `/admin`: 管理ダッシュボード(管理者)

## 5. 機能仕様(要点)
- QR出席: 署名トークン+セッション検証で改ざん防止
- 入室/退室: 2回スキャンで滞在時間を記録
- 出席ポリシー: 遅刻/締切/早退/警告閾値/レート制限
- 監査ログ: 変更理由必須、CSV出力、条件保存
- 申請承認: 欠席/遅刻/公欠の申請と承認/却下
- 承認ワークフロー: 出席修正/確定/解除/CSV反映
- 不正検知: 失敗多発/異常IP/端末制限違反を通知
- レポート: 週次/日次推移、要注意者、期末PDF/CSV
- 連携: APIキー + スコープ認可
- 端末管理: 公認端末の登録/承認
- SSO設定: OIDC/SAML設定値の保持

## 6. データモデル(代表)
- `users`, `school_classes`, `enrollments`, `class_sessions`
- `attendance_records`, `attendance_requests`, `attendance_changes`
- `attendance_policies`, `qr_sessions`, `qr_scan_events`
- `notifications`, `operation_requests`, `audit_saved_searches`
- `roles`, `permissions`, `role_permissions`, `devices`, `api_keys`, `sso_providers`

## 7. 非機能要件
- 日本語UI、モバイル対応、監査性重視
- タイムゾーン: Asia/Tokyo
- HTTPS強制(本番)

## 8. 環境変数
- `DATABASE_URL`
- `RAILS_MASTER_KEY`
- `APP_HOST`
- `RAILS_ENV`
- `RAILS_SERVE_STATIC_FILES`
- `QR_TOKEN_SECRET`

## 9. デプロイ(Render)
- Build: `bin/render-build.sh`
- Start: `bundle exec puma -C config/puma.rb`

## 10. 運用メモ
- 定期確定: `bin/rails attendance:finalize`
- デモ: `bin/rails demo:seed` / `bin/rails demo:reset`
- 監査ログ: `/attendance-logs`, `/scan-logs`
