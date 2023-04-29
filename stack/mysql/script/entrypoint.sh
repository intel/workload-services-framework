#!/bin/bash
/prepare_database.sh
/usr/local/bin/docker-entrypoint.sh "$@"
