#!/bin/bash

set -eu

webroot=$1
target_dir=$2
mail=$3
domain=$4
env=$5

certbot_path="/etc/letsencrypt/live/$domain"

if [ "$env" == "production" ]; then
certbot \
  certonly \
  --test-cert \
  -n \
  --agree-tos \
  --webroot \
  --webroot-path "$webroot" \
  -m "$mail" \
  -d "$domain"
else
  mkdir -p "$certbot_path"

  openssl req -x509 -newkey rsa:2048 \
    -keyout "${certbot_path}/privkey.pem" \
    -out "${certbot_path}/fullchain.pem" \
    -nodes \
    -days 365 \
    -subj "/C=DE/L=Test/OU=Test/CN=${domain}"
fi


cp -Lr \
  "$certbot_path" \
  "$target_dir"

cat "$target_dir/$domain/privkey.pem" "$target_dir/$domain/fullchain.pem" >"$target_dir/$domain/cert.pem"
