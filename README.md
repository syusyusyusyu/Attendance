# 学校の出席管理システム (Rails 8 + Hotwire + PostgreSQL)

## 概要
学校向けの出席管理を、QR入室/退室と申請/監査/レポートで完結させるWebアプリです。
教員・学生・管理者の3ロールで運用し、実運用を想定した承認フローと監査性を備えています。

## 主な機能
- QRセッション発行と署名トークン検証による出席登録
- 入室/退室による滞在時間の記録と早退判定
- 出席申請(欠席/遅刻/公欠)と承認ワークフロー
- 出席確定/確定解除/CSV反映の承認フロー
- 監査ログ(出席変更/QRスキャン)の検索とCSV出力
- レポート(週次/日次推移、要注意者抽出、期末PDF/CSV)
- 管理者向け管理画面(ユーザー/権限/監査/承認/端末/SSO/API)
- 公認端末の登録/承認(任意)
- APIキー + スコープ認可による学務連携

## クイックスタート
```bash
bundle install
bin/rails db:setup
bin/rails server
```

## 初期ログイン
- 管理者: `admin@example.com` / `password`
- 教員: `teacher@example.com` / `password`
- 学生: `student@example.com` / `password`

## Render デプロイ
- 環境変数
  - `DATABASE_URL`
  - `RAILS_MASTER_KEY`
  - `RAILS_ENV=production`
  - `RAILS_SERVE_STATIC_FILES=1`
  - `APP_HOST` (例: `attendance.example.com`)
  - `QR_TOKEN_SECRET` (QR署名用の秘密鍵)
- Build Command: `bin/render-build.sh`
- Start Command: `bundle exec puma -C config/puma.rb`

## 運用メモ
- 定期確定: `bin/rails attendance:finalize` をCronで実行
- デモデータ: `bin/rails demo:seed` / `bin/rails demo:reset`
- 運用ガイド: `OPERATION_GUIDE.md`
- デモ手順: `DEMO.md`
- 仕様書: `仕様書.md`
