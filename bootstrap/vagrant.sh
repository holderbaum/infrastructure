#!/bin/bash

# Specific commands to bootstrap vagrant

set -eu

# Enable root ssh access over vagrant
cat /home/ubuntu/.ssh/authorized_keys >> /root/.ssh/authorized_keys
