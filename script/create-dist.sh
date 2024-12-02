#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -z "$1" ]; then
  echo "Usage: <source-dir>"
  exit 3
fi

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
PREFIX=src

for env in "$1"/env/*.env; do
  if [ -r "$env" ]; then
    . "$env"
  fi
done

rm -rf $PREFIX

if [[ "$UPSTREAM_REPO" = "https://"* ]]; then
  echo git clone --depth 1 -b $UPSTREAM_BRANCH $UPSTREAM_REPO $PREFIX
  git clone --depth 1 -b $UPSTREAM_BRANCH $UPSTREAM_REPO $PREFIX
  cd $PREFIX
  for dir1 in ${DIST_DIRS[@]}; do
    echo git rm -rf "${dir1}"
    git rm -rf "${dir1}" 2> /dev/null || true
  done
else
  mkdir $PREFIX
  cd $PREFIX
fi

copy_file () {
  cp -f "$2" "$3"

  # add license header
  for license in "$1"/license/*; do
    name="${license/*\//}"
    if [ -r "$license" ] && ([[ "$license" = *"*" ]] && [[ "${3/*\//}" = "${name%'*'}"* ]] || [[ "${3/*\//}" = *".$name" ]]); then
      i=$(( $(sed -n '{/^\s*$/{q};/^changecom(.*)\s*$/{p;d};/^[^#]/{q};p}' "$3" | wc -l) + 1 ))
      while IFS= read line; do
        [ "$(sed -n "$i{p}" "$3")" = "$line" ] || sed -i "${i}i${line:-\\}" "$3"
        i=$(( i + 1 ))
      done < <(cat "$license")
    fi
  done
}

for bom in "$1"/bom/*.txt; do
  echo "Processing $bom..."
  for file1 in $(cat "$bom"); do
    if [ -f "$DIR/../$file1" ]; then
      mkdir -p "$(dirname "$file1")"
      copy_file "$1" "$DIR/../$file1" "$file1"
      if [ -n "$UPSTREAM_REPO" ]; then
        echo git add "$file1"
        git add -f "$file1"
      fi
    fi
  done
done

if [ -d "$1"/overlay ]; then
  for file1 in $(cd $1/overlay; find . -type f -print | sed 's|^./||'); do
    echo "Copying $1/overlay/$file1"
    copy_file "$1" "$1/overlay/$file1" "$file1"
    if [ -n "$UPSTREAM_REPO" ]; then
      echo git add "$file1"
      git add -f "$file1"
    fi
  done
fi

for script1 in "$1"/script/*; do
  if [ -x "$script1" ]; then
    "$script1"
  fi
done

for file1 in "$1"/legal/*; do
  if [ -r "$file1" ]; then
    eval "legal_files=($(head -n1 "$file1" | sed 's/^# //'))"
    IFS=$'\n' legal_verbage=($(sed '1d' "$file1"))
    for file2 in "${legal_files[@]}"; do
      legal_update=0
      status=$(grep -rn $file2 "$1"/bom || [[ $? == 1 ]])
      if [ "$status" == "" ] && [ ! -r "$1"/overlay/"$file2" ]; then legal_update=1; fi
      if [ -r "$file2" ] && [ $legal_update -eq 0 ]; then
        for i in $(seq 1 ${#legal_verbage[@]}); do
          sed -i "${i}i${legal_verbage[$((i-1))]}" "$file2"
          if [ -n "$UPSTREAM_REPO" ]; then
            echo git add "$file2"
            git add -f "$file2"
          fi
        done
      fi
    done
  fi
done

for file1 in "$1"/check/*; do
  if [ -r "$file1" ]; then
    if grep -rn -w -E "$(cat "$file1")" --exclude-dir=.git .; then
      exit 3
    fi
  fi
done
