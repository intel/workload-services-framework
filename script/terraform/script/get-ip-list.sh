#!/bin/bash

if [ -r "$1" ]; then
    grep -v -E '^\s*#' "$1"
else
    proxy_ip="$(curl -s ifconfig.me)"
    if [ "$proxy_ip" = "$(curl -s ipecho.net/plain)" ]; then
      echo "$proxy_ip/32"
    else
      echo "$(hostname -I | cut -f1 -d' ')/32"
    fi
fi

