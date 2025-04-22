#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$(dirname "$(readlink -f "$0")")"
csps="$(sed -n '/^ *csp *=/{s/.*"\(.*\)".*$/\1/;p}' "$DIR"/terraform/terraform-config.*.tf | tr '\n' ' ')"

backend="terraform"
setup_dev_options=()
cmake_options=()
make_build_options=()
make_csp_options=()
ctest_options=()
listkpi_options=()
last=""
for argv in "$@"; do
  case "$argv" in
  --help)
    echo "Usage: [options]"
    echo "--self [<value>]         Create a loop-back SUT configuration."
    echo "-D <var>=<value>         Pass the variable definitions to cmake."
    echo "--format <value>         Pass the --format option to listkpi."
    echo "--params                 Pass the --params option to listkpi."
    echo "<csp>|bom|build_*|bom_*  Pass target definitions to make."
    echo "<others>                 Pass variable definitions to ctest."
    exit 0
    ;;
  --self=*|--self)
    setup_dev_options+=("$argv")
    cmake_options+=("-D${backend^^}_SUT=self")
    ;;
  -DBACKEND=*)
    backend="${argv#-DBACKEND=}"
    cmake_options+=("$argv")
    ;;
  -D*=*|-D)
    cmake_options+=("$argv")
    ;;
  --format=*|--params=*|--format|--params)
    listkpi_options+=("$argv")
    ;;
  *)
    case "$last" in
    -D)
      [ "${argv%=*}" != "BACKEND" ] || backend="${argv#*=}"
      cmake_options+=("$argv")
      ;;
    --format)
      listkpi_options+=("$argv")
      ;;
    *)
      case "$argv" in
      bom|build_*|bom_*)
        make_build_options+=("$argv")
        ;;
      *"@"*)
        if [ "$last" = "--self" ]; then
          setup_dev_options+=("$argv")
        else
          ctest_options+=("$argv")
        fi
        ;;
      *)
        if [[ " $csps " = *" $argv "* ]]; then
          make_csp_options+=("$argv")
        else
          ctest_options+=("$argv")
        fi
        ;;
      esac
      ;;
    esac
    ;;
  esac
  last="$argv"
done

if [ ! -e build ]; then
  script/setup/setup-dev.sh "${setup_dev_options[@]}"
fi

mkdir -p build
cd build

cmake "${cmake_options[@]}" ..
if [ ${#make_csp_options[@]} -gt 0 ] && [ "$backend" = "terraform" ]; then
  make build_terraform
  make "${make_csp_options[@]}"
fi
make "${make_build_options[@]}"

if [ ${#ctest_options[@]} -gt 0 ]; then
  ./ctest.sh "${ctest_options[@]}" -V
  ./list-kpi.sh "${listkpi_options[@]}" --recent
fi
