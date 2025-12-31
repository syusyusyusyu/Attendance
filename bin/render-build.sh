#!/usr/bin/env bash
set -e

export BUNDLE_WITHOUT="${BUNDLE_WITHOUT:-development:test}"
export BUNDLE_PATH="${BUNDLE_PATH:-/opt/render/project/.gems}"

bundle binstubs bundler --force
bundle install --jobs=4 --retry=3
bundle exec rails assets:precompile
bundle exec rails db:migrate db:seed
