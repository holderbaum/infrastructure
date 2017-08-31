#!/bin/bash

set -eu

export TF_VAR_do_token="${DIGITAL_OCEAN_API_TOKEN}"

function ensure_terraform {
  if [ ! -f tmp/terraform ]; then
      download_terraform
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
  test -f tmp/terraform || return

  tmp/terraform "$@"
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

function task_prepare_ci {
  sudo apt-get install -y software-properties-common
  sudo apt-add-repository -y ppa:ansible/ansible
  sudo apt-get update -y
  sudo apt-get install -y ansible
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

  {
    echo "Host turing.example.org"
    echo "  HostName ${ip}"
    echo "  User root"
    echo "  IdentityFile ./tmp/test_rsa_id"
    echo "  UserKnownHostsFile /dev/null"
    echo "  StrictHostKeyChecking no"
  } > tmp/ssh-config

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
  ensure_terraform
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
  prepare-ci) task_prepare_ci ;;
  deploy) task_deploy "$@" ;;
  test) task_test "$@" ;;
  clean) task_clean ;;
  *) task_usage ;;
esac
