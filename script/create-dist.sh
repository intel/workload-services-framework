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

create_view () {
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
    for dir1 in $UPSTREAM_REMOVE; do
      echo git rm -rf "${dir1}"
      git rm -rf "${dir1}" 2> /dev/null || true
    done
    for dir1 in $UPSTREAM_IGNORE; do
      echo rm -rf "${dir1}"
      rm -rf "${dir1}" 2> /dev/null || true
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
        i=$(( $(sed -n '{/^\s*$/{q};/^changecom(.*)/{p;d};/^[^#]/{q};p}' "$3" | wc -l) + 1 ))
        while IFS= read line; do
          [ "$(sed -n "$i{p}" "$3")" = "$line" ] || sed -i "${i}i${line:-\\}" "$3"
          i=$(( i + 1 ))
        done < <(cat "$license")
      fi
    done
  }

  rc=0
  for bom in "$1"/bom/*.txt; do
    echo "Processing $bom..."
    for file1 in $(cat "$bom"); do
      if [ -f "$DIR/../$file1" ]; then
        mkdir -p "$(dirname "$file1")"
        copy_file "$1" "$DIR/../$file1" "$file1"
        if [ -n "$UPSTREAM_REPO" ]; then
          git add -f "$file1"
        fi
      else
        echo "  missing $file1"
        rc=1
      fi
    done
  done
  [ $rc -eq 0 ] || exit 3

  if [ -d "$1"/overlay ]; then
    for file1 in $(cd $1/overlay; find . -type f -print | sed 's|^./||'); do
      echo "Copying $1/overlay/$file1"
      copy_file "$1" "$1/overlay/$file1" "$file1"
      if [ -n "$UPSTREAM_REPO" ]; then
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
              git add -f "$file2"
            fi
          done
        fi
      done
    fi
  done

  for file1 in "$1"/check/*; do
    if [ -r "$file1" ]; then
      if grep -rn -w -E "$(cat "$file1")" --exclude-dir=.git . <(find . -type f -print); then
        exit 3
      fi
    fi
  done

  if [[ "$UPSTREAM_REPO" = "https://"* ]]; then
    for dir1 in $UPSTREAM_IGNORE; do
      echo git checkout "${dir1}"
      rm -rf "${dir1}" 2> /dev/null || true
      git checkout "${dir1}" 2> /dev/null || true
    done
  fi
}

create_release () {
  release_tag="${BENCHMARK#dist/hybrid/}"
  root_path="$(pwd)/$release_tag"
  rm -rf "$root_path"
  mkdir -p "$root_path"

  cd "$PROJECTROOT"
  git archive tags/$release_tag | tar xf - -C "$root_path"
  rm -rf "$root_path"/script "$root_path"/CMakeLists.txt
  cp -rf CMakeLists.txt script workload/platforms "$root_path"
  mkdir -p "$root_path"/build

  cd "$root_path"/build
  cmake -DPLATFORM=$PLATFORM -DBACKEND=$BACKEND -DREGISTRY= -DREGISTRY_AUTH=$REGISTRY_AUTH -DRELEASE=$release_tag -DTIMEOUT=$TIMEOUT -DTERRAFORM_REGISTRY=$REGISTRY -DTERRAFORM_RELEASE=$RELEASE -DTERRAFORM_SUT="$TERRAFORM_SUT" -DTERRAFORM_OPTIONS="$TERRAFORM_OPTIONS" -DSPOT_INSTANCE=$SPOT_INSTANCE ..

  echo "workload_commit: \"tags/$release_tag\"" >> "$root_path/.hybrid_release"
  echo "workload_branch: \"${release_tag#v}\"" >> "$root_path/.hybrid_release"

  echo
  echo -e "*** \033[31mExperimental feature. Not all workloads work under mixed release versions.\033[0m ***"
  echo

  echo "Mixed version distribution created at ${root_path#"$BUILDROOT/"}, with workload @$release_tag and infrastructure @${RELEASE#:}"
  echo "Evaluate workloads as follows:"
  echo
  echo "cd ${root_path#"$BUILDROOT/"}/build"
  echo "cmake .."
  echo
  echo -e "*** \033[31mDo not modify workload source as code is not tracked.\033[0m ***"
  echo
}

create_archive () {
  if [ -x script/dist-start.sh ] && makeself --version > /dev/null 2>&1; then
    makeself --tar-extra "--exclude=.git" --nox11 --notemp --nooverwrite --help-header <(script/dist-start.sh --help;echo -e "\t";echo -e "\t") . "../${BENCHMARK##*/}.run" "$BENCHMARK$RELEASE" ./script/dist-start.sh
  fi
}

if [[ "$BENCHMARK" = "dist/hybrid/"* ]]; then
  create_release $@
else
  create_view $@
  create_archive $@
fi
