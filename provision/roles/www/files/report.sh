#!/bin/bash

set -eu

for log_file in /data/static_sites/*/access.log;
do
  if [ "$(cat "$log_file" |wc -l)" -gt 0 ];
  then
    report_dir="$(dirname "$log_file")/report"
    name="$(basename "$(dirname "$log_file")")"
    user="deploy-$name"
    group="deploy-$name"
    mkdir -p "$report_dir"
    goaccess -g -a "$log_file" -o "$report_dir/index.html" --log-format=COMBINED
    chown -R "${user}:${group}" "$report_dir"
  else
    echo "Skipping empty $log_file"
  fi
done
