# デモシナリオ

## 事前準備
1. `bin/rails db:setup`
2. `bin/rails demo:seed`

### Render DBの内容をデモとして使う場合
- `DEMO_SOURCE_DATABASE_URL` を指定して同期します。
  - 例: `DEMO_SOURCE_DATABASE_URL=... bin/rails demo:sync`
- 同期は現在のDBを上書きするため、デモ用DBでのみ実行してください。

## デモ用アカウント
- 管理者: `admin@example.com` / `password`
- 教員: `teacher@example.com` / `password`
- 学生: `student@example.com` / `password`

※ `DEMO_SOURCE_DATABASE_URL` で同期した場合は、Render側のユーザー情報に依存します。

## デモ手順
1. 教員でログイン → 「QRコード生成」から授業を選択しQRを表示
2. 学生でログイン → 「QRコードスキャン」で入室登録
3. 同じ学生で再度スキャン → 退室登録(滞在時間/早退判定を確認)
4. 学生が「出席申請」を送信 → 教員が承認/却下
5. 教員が「出席確認」で出席を確定 → 自動欠席確定と通知を確認
6. 「レポート」で週次/日次推移と期末レポート(PDF/CSV)を確認
7. 管理者でログイン → 操作申請を確認

## リセット
- `bin/rails demo:reset` でデモデータを削除できます。
