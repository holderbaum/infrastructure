#!/bin/bash

set -eu

function ensure_bundle {
  if [ ! -d vendor/bundle ]; then
      bundle install --path vendor/bundle
  fi

  if [ Gemfile -nt vendor/bundle -o Gemfile.lock -nt vendor/bundle ]; then
      bundle
      touch vendor/bundle
  fi
}

function execute_provisioning {
  local host="$1"
  local config="$2"

  ansible-playbook \
    -i "${host}," \
    --ssh-common-args="-F ${config}" \
    provision/site.yml
}

function task_deploy {
  execute_provisioning turing.holderbaum.me ./deploy/ssh-config
}

function task_test {
  ensure_bundle
  bundle exec rubocop -f emacs

  if ! vagrant status |grep running &>/dev/null;
  then
    vagrant up
  fi

  vagrant ssh-config > .vagrant/ssh-config
  execute_provisioning "turing.example.org" ".vagrant/ssh-config"

  bundle exec rspec
}

function task_usage {
  echo "usage: $0 deploy | test"
  exit 255
}

task="${1:-}"
case "$task" in
  deploy) task_deploy ;;
  test) task_test ;;
  *) task_usage ;;
esac
