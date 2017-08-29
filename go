#!/bin/bash

set -eu

function ensure_bundle {
  if [ ! -d vendor/bundle ]; then
      bundle install --path vendor/bundle
  fi

  if [ Gemfile -nt vendor/bundle ] || [ Gemfile.lock -nt vendor/bundle ]; then
      bundle
      touch vendor/bundle
  fi
}

function execute_provisioning {
  local target="$1"
  local known_hosts="$2"
  local private_key="${3:-}"
  local ansible_vars=''
  shift

  local host

  if [[ "$target" == *":"* ]]; then
    host="$(echo "$target" |cut -d':' -f1)"
    ansible_vars+=" ansible_host=$(echo "$target" |cut -d':' -f2)"
  else
    host="$target"
  fi

  if [[ "$known_hosts" == "no-host-checking" ]]; then
    ansible_vars+=" ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'"
  else
    ansible_vars+=" ansible_ssh_common_args='-o UserKnownHostsFile=${known_hosts}'"
  fi

  if [[ -n "$private_key" ]]; then
    ansible_vars+=" ansible_ssh_private_key_file='$private_key'"
  fi

  ansible-playbook \
    --inventory-file=./provision/hosts \
    --limit="$host" \
    --vault-password-file ./provision/get-vault-pass.sh \
    --extra-vars="$ansible_vars" \
    provision/site.yml
}

function task_deploy {
  execute_provisioning \
    turing.holderbaum.me \
    ./deploy/known_hosts
}

function setup_vagrant {
  if vagrant status |grep active &>/dev/null; then
    return 0
  fi

  mkdir -p tmp

  if [ ! -f tmp/test_rsa_id ]; then
    ssh-keygen -t rsa -b1024 -f tmp/test_rsa_id -N ''
  fi

  vagrant up

  vagrant ssh-config > tmp/ssh-config

  grep HostName tmp/ssh-config |cut -d' ' -f4 > tmp/vagrant-host-ip
}

function task_test {
  ensure_bundle
  bundle exec rubocop -f emacs

  setup_vagrant

  local ip
  ip="$(cat ./tmp/vagrant-host-ip)"

  execute_provisioning \
    "turing.example.org:${ip}" \
    'no-host-checking' \
    './tmp/test_rsa_id'

  bundle exec rspec -f d
}

function task_clean {
  vagrant destroy -f || true
  rm -fr tmp .vagrant
}

function task_usage {
  echo "usage: $0 deploy | test"
  exit 255
}

task="${1:-}"
shift || true
case "$task" in
  deploy) task_deploy "$@" ;;
  test) task_test "$@" ;;
  clean) task_clean ;;
  *) task_usage ;;
esac
