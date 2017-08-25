#!/bin/bash

set -eu

webroot=$1
target_dir=$2
mail=$3
domain=$4

certbot \
  certonly \
  --test-cert \
  -n \
  --agree-tos \
  --webroot \
  --webroot-path "$webroot" \
  -m "$mail" \
  -d "$domain"

cp -Lr \
  "/etc/letsencrypt/live/$domain" \
  "$target_dir"

cat "$target_dir/$domain/privkey.pem" "$target_dir/$domain/fullchain.pem" >"$target_dir/$domain/cert.pem"
