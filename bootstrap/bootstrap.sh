#!/bin/bash

set -eu

# My default public key
pubkey='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDKYz+/rIGI0oGPN1T/u40uTQ9+iahwu3e+3lSmLiRfJCjc/Pb3UEHvY6NwmUgsK6oyPQ46ub+A5tiMQdZFClXccBLy3sYKsgRNMEMn6PXGmsALAVq3H3HlRhlsb/Ya8k+bl8kHvQ/QiQJwXECYT7OjW0BErbhR+4s/Z/8C3ZM+ypjMDgolBCkyaWdfm3wNz8A8247oWqIcmPaoxMCH7yVkTfeL2jFCqwg87GQr1lf7dDxM37M+bLrpW1XQSlOsMc+gLhF01WrlNEELdlWOqoGQvH9Vuqa42iaDah/aAkmWN4yTuJgwxbYWmZ1qXrII4PCn5exdSkx7wnZHZ/7mR378OfaGKxilGgOntVnnRUtvmHaN+CwHbkpf3HddZhzY0kmV0dRHs/WgfqVPTxBnkR8VKJWhEh4vK2NaclKt4jkPQ78/zxdCfIm7+BLAb+ZmF7/U/GP0AcS56VAMWNYwtiOEBEsJIvFcphWPlCTH4DgyolEpbPBfM74EhdAhuQ+HL5oGkdEBjAGHJQYaKSof5fiVoFfex42XeCwgxtPc4DqdBRgMP7VhCTOBdVSs6iUpuDGFakZs7FpVqJBXMihK6Ew30CsAoZdtxHY2Uc4XxG7LskCDA0RpVyS+ZfFHZEjBWjnrXJL3eyb9lnh0lXDW+igd3qdAbBvXQOqRLKrveGp2Rw== jakob'

set -x

# Disable root password
passwd -dl root

# Make root accessible from ssh
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "${pubkey}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/

# Install ansible dependencies
apt-get update
apt-get install -y python python-pip
