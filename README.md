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


## 追加: QR本格導入のポイント
- カメラQRスキャン(BarcodeDetector + jsQRフォールバック)対応、カメラ非対応端末は手入力にフォールバック
- QR発行はQrSessionとして保存し、再生成時に既存セッションを失効
- QRコードは自動ローテーションで更新(60秒間隔)
- スキャンログ(QrScanEvent)に成功/失敗/理由/端末情報を記録
- 教員ダッシュボードに本日の出席率サマリーを表示
- `/attendance` からCSVダウンロードが可能
- 出席ポリシー(遅刻/締切/開始前許可)で自動判定
- 入室/退室を記録し、滞在時間で早退判定

## 追加: 環境変数
- `QR_TOKEN_SECRET` : QRトークン署名用の秘密鍵(変更すると既存トークンは無効)

## 追加: カメラ対応ブラウザ
- Chromium系 (Chrome / Edge / Brave / Opera / Samsung Internet) でBarcodeDetectorが動作
- iOS Safari 16+ はjsQRフォールバックで利用可能
- それ以外のブラウザ/アプリ内ブラウザは手入力フォールバックを利用

## 追加: CSVエクスポート仕様
- 期間指定: `start_date` / `end_date` (同日なら1日分)
- 追加項目: 授業回ID、入室時刻、退室時刻、滞在分、申請状況/種別/理由、QRセッションID、IP、UserAgent、備考

## 追加: CSVインポート仕様
- 必須列: 日付 / 学生ID / 出席状況
- 出席状況は `出席/遅刻/欠席/公欠/早退` (英語ラベルも可)
- `入室時刻/退室時刻/滞在分` は任意
- `未入力` はスキップ

## 追加: 監査ログ
- `/scan-logs` でQRスキャンログを確認可能

## 追加: 運用強化
- クラス管理/名簿インポート/特別日程(休講・補講)
- 出席修正理由の必須化 + 変更ログ `/attendance-logs`
- レポート `/reports` で出席傾向を可視化
- 通知 `/notifications` で更新を確認
- QRスキャンのIP/端末制限・分間スキャン上限
- QRスキャン結果が出席管理画面にリアルタイム反映
- 出席申請(欠席/遅刻/公欠)の申請・承認フロー
- 出席確定/解除と自動欠席確定 (`bin/rails attendance:finalize`)
