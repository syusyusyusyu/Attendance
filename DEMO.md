# デモシナリオ

## 事前準備
1. `bin/rails db:setup`
2. `bin/rails demo:seed`

## デモ用アカウント
- 教員: `demo_teacher@example.com` / `password`
- 学生: `demo_student1@example.com` / `password`

## デモ手順（5分想定）
1. 教員でログイン → 「QRコード生成」から授業を選択してQRを表示。
2. 学生でログイン → 「QRコードスキャン」から入室登録。
3. 同じ学生で再度スキャン → 退室登録（早退判定の表示を確認）。
4. 学生が「出席申請」を送信 → 教員が承認/却下。
5. 教員が「出席確認」で出席を確定 → 自動欠席確定と通知を確認。
6. 「レポート」から週次/日次推移と期末レポート(PDF/CSV)を確認。

## リセット
- `bin/rails demo:reset` でデモデータを削除できます。
