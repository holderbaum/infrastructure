#!/bin/bash

set -eu

_webroot=$1
target_dir=$2
_mail=$3
domain=$4

path="$target_dir/$domain"

openssl req -x509 -newkey rsa:2048 \
  -keyout "${path}/privkey.pem" \
  -out "${path}/fullchain.pem" \
  -nodes \
  -days 365 \
  -subj "/C=DE/L=Test/OU=Test/CN=${domain}"
