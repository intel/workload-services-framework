#!/bin/bash -e
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
FIND_OPTIONS="-name *.intel"
. "$DIR/../../script/build.sh"
