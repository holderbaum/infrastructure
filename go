#!/bin/bash

set -eu

export TF_VAR_do_token="${DIGITAL_OCEAN_API_TOKEN}"
export TERRAFORM_PATH

function ensure_terraform {
  if [ -z "${TERRAFORM_PATH:-}" ]; then
    if which terraform &>/dev/null; then
      TERRAFORM_PATH="$(which terraform)"
    else
      download_terraform
      TERRAFORM_PATH="$(pwd)/tmp/terraform"
    fi
  fi
}

function download_terraform {
  if [ ! -f tmp/terraform ]; then
  mkdir -p tmp
  curl -Lo tmp/tf.zip https://releases.hashicorp.com/terraform/0.10.2/terraform_0.10.2_linux_amd64.zip
    (
      cd tmp
      unzip tf.zip
      rm tf.zip
    )
  fi
}

function terraform {
  test -n "${TERRAFORM_PATH:-}" || return 1

  ${TERRAFORM_PATH} "$@"
}


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

function setup_test_machine {
  ensure_terraform

  mkdir -p tmp

  if [ ! -f tmp/test_rsa_id ]; then
    ssh-keygen -t rsa -b1024 -f tmp/test_rsa_id -N ''
  fi

  local ip

  terraform init
  terraform apply
  ip="$(terraform output ip)"

  echo "Host turing.example.org" > tmp/ssh-config
  echo "  HostName ${ip}" >> tmp/ssh-config
  echo "  User root" >> tmp/ssh-config
  echo "  IdentityFile ./tmp/test_rsa_id" >> tmp/ssh-config
  echo "  UserKnownHostsFile /dev/null" >> tmp/ssh-config
  echo "  StrictHostKeyChecking no" >> tmp/ssh-config

  echo "$ip" >tmp/host-ip

  # wait for host to come online
  # ssh -q -F tmp/ssh-config turing.example.org exit
}

function task_test {
  ensure_bundle
  bundle exec rubocop -f emacs

  setup_test_machine

  local ip
  ip="$(cat ./tmp/host-ip)"

  execute_provisioning \
    "turing.example.org:${ip}" \
    'no-host-checking' \
    './tmp/test_rsa_id'

  bundle exec rspec -f d
}

function task_clean {
  terraform destroy -force || true
  rm -fr tmp terraform.tfstate*
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
