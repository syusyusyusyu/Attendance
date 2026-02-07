namespace :webpush do
  desc "VAPID公開鍵/秘密鍵ペアを生成し、.env用フォーマットで出力"
  task generate_keys: :environment do
    vapid_key = WebPush.generate_key

    puts "VAPID鍵を生成しました。以下を .env にコピーしてください:"
    puts ""
    puts "WEBPUSH_PUBLIC_KEY=#{vapid_key.public_key}"
    puts "WEBPUSH_PRIVATE_KEY=#{vapid_key.private_key}"
    puts ""
    puts "※ 鍵を変更すると既存のPush購読が無効になります。本番環境では慎重に管理してください。"
  end
end
