#!/usr/bin/env bash
set -e

bundle binstubs bundler --force
bundle install
bundle exec rails assets:precompile
bundle exec rails db:migrate db:seed
