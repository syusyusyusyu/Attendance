#!/usr/bin/env bash
set -e

bundle install
bundle exec rails assets:precompile
bundle exec rails db:migrate
