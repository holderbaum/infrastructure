#!/bin/bash

set -eu

username=$1
domain=$2
password=$3

ejabberdctl=/opt/ejabberd/bin/ejabberdctl

$ejabberdctl check_account "$username"  "$domain" && exit 0


$ejabberdctl register "$username" "$domain" "$password"
