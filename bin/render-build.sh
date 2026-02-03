#!/usr/bin/env bash
set -e

export BUNDLE_WITHOUT="${BUNDLE_WITHOUT:-development:test}"
export BUNDLE_PATH="${BUNDLE_PATH:-/opt/render/project/.gems}"

bundle install --jobs=4 --retry=3
bundle binstubs bundler --force
bundle exec rails assets:precompile
bundle exec rails db:migrate

# DEMO_RESET環境変数がtrueの場合、デモデータを再生成
if [ "$DEMO_RESET" = "true" ]; then
  echo "=== DEMO_RESET enabled: Resetting demo data ==="
  bundle exec rails demo:reset demo:seed
else
  bundle exec rails db:seed
fi
