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

function task_test {
  ensure_bundle
  bundle exec rubocop -f emacs

  if ! vagrant status |grep running &>/dev/null;
  then
    vagrant up
  fi

  vagrant ssh-config > .vagrant/ssh-config
  ansible-playbook \
    -i 'default,' \
    --ssh-common-args='-F ./.vagrant/ssh-config' \
    provision/site.yml

  bundle exec rspec
}

function task_usage {
  echo "usage: $0 test"
  exit 255
}

task="${1:-}"
case "$task" in
  test) task_test ;;
  *) task_usage ;;
esac
