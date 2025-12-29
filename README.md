学校の出席管理システム (Rails 8 + Hotwire + PostgreSQL)

## 開発セットアップ (WSL2)
```bash
cd /mnt/c/Users/cafec/OneDrive/Desktop/tables勉強用/school

~/.rbenv/shims/bundle install
~/.rbenv/shims/rails db:create db:migrate db:seed
~/.rbenv/shims/bin/dev
```

## 初期ログイン
- 教員: `teacher@example.com` / `password`
- 学生: `student@example.com` / `password`

## Render デプロイ準備
- 環境変数
  - `DATABASE_URL` (Renderが発行するPostgreSQL URL)
  - `RAILS_MASTER_KEY` (config/master.key の内容)
  - `RAILS_ENV=production`
  - `RAILS_SERVE_STATIC_FILES=1`
 - Build Command (Render)
   - `bin/render-build.sh`

## よく使うコマンド
```bash
~/.rbenv/shims/rails db:create db:migrate db:seed
~/.rbenv/shims/rails db:reset
~/.rbenv/shims/bin/dev
```

