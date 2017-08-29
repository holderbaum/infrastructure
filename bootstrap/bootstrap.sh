#!/bin/bash

set -eu

# Install ansible dependencies
if [ ! -e /usr/bin/python ];
then
  apt-get update
  apt-get install -y \
      python-yaml \
      python-paramiko \
      python-jinja2
fi
