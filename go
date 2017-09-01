#!/bin/bash

set -eu

export TF_VAR_do_token
export TERRAFORM
export TERRAFORM_STATE

TF_VAR_do_token="${DIGITAL_OCEAN_API_TOKEN}"
TERRAFORM="$(pwd)/tmp/terraform"
TERRAFORM_STATE="$(pwd)/tmp/terraform.tfstate"

function ensure_terraform {
  if [ ! -f "$TERRAFORM" ]; then
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
  test -f "$TERRAFORM" || return

  "$TERRAFORM" "$@"
}


function ensure_bundle {
  if [ ! -d .vendor/bundle ]; then
      bundle install --path .vendor/bundle
  fi

  if [ Gemfile -nt .vendor/bundle ] || [ Gemfile.lock -nt .vendor/bundle ]; then
      bundle
      touch .vendor/bundle
  fi
}

function task_prepare_ci {
  sudo apt-get install -y software-properties-common
  sudo apt-add-repository -y ppa:ansible/ansible
  sudo apt-get update -y
  sudo apt-get install -y \
    ansible \
    autossh
}

function setup_test_machine {
  ensure_terraform

  mkdir -p tmp

  if [ ! -f tmp/test_rsa_id ]; then
    ssh-keygen -t rsa -b1024 -f tmp/test_rsa_id -N ''
  fi

  terraform init -input=false
  terraform apply -input=false -state="$TERRAFORM_STATE"

  local ip
  ip="$(terraform output -state="$TERRAFORM_STATE" ip)"

  {
    echo "Host turing.example.org"
    echo "  HostName ${ip}"
    echo "  User root"
    echo "  IdentityFile ./tmp/test_rsa_id"
    echo "  UserKnownHostsFile /dev/null"
    echo "  StrictHostKeyChecking no"
    echo "  ConnectTimeout 20"
  } >tmp/ssh-config

  set +e
  # Verify connection
  local attempts=0
  while ! ssh -F ./tmp/ssh-config turing.example.org uptime; do
    (( attempts++ ))
    if [ $attempts -eq 10 ]; then
      echo 'Could not connect to test machine'
      exit 1
    fi
    sleep 1
  done
  set -e
}

function task_lint {
  ensure_bundle
  bundle exec rubocop -f emacs
  bundle exec travis lint -x
}



function task_test {
  task_lint

  setup_test_machine

  ansible-playbook \
    --inventory-file=./inventories/test/ \
    --extra-vars="ansible_ssh_common_args='-F ./tmp/ssh-config'" \
    provision/site.yml

  bundle exec rspec --format documentation
}

function task_deploy {
  task_lint

  ansible-playbook \
    --inventory-file=./inventories/production/ \
    --extra-vars="ansible_ssh_common_args='-F ./inventories/production/ssh-config'" \
    --vault-password-file ./inventories/production/get-vault-pass.sh \
    provision/site.yml
}

function task_clean {
  ensure_terraform
  terraform destroy -force -input=false -state="$TERRAFORM_STATE"
  rm -fr tmp
}

function task_usage {
  echo "usage: $0 lint | deploy | test | clean"
  exit 255
}

task="${1:-}"
shift || true
case "$task" in
  prepare-ci) task_prepare_ci ;;
  lint) task_lint ;;
  deploy) task_deploy "$@" ;;
  test) task_test "$@" ;;
  clean) task_clean ;;
  *) task_usage ;;
esac
