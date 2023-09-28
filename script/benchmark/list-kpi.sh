#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$(dirname "$(readlink -f "$0")")"

print_help () {
    echo "Usage: [options] logsdir"
    echo "--primary             List only the primary KPI."
    echo "--all                 List all KPIs."
    echo "--params              Print out all configuration parameters."
    echo "--svrinfo             Print out svrinfo."
    echo "--outlier <n>         Drop samples beyond N-stdev."
    echo "--format <format>     Specify the output format: list, xls-ai, xls-inst, or xls-table."
    echo "--var[1-9] value      Specify spreadsheet variables."
    echo "--file filename       Specify the spreadsheet filename."
    echo "--filter filter       Specify the trim filter to shorten the worksheet name."
    echo "--uri                 Show WSF portal URI."
    echo "--intel_publish       Publish logs to the WSF dashboard."
    echo "--owner <name>        Set publisher owner."
    echo "--tags <tags>         Set publisher tags."
    exit 0
}

prefixes=()
primary=1
outlier=0
printvar=0
format="list"
xlsfile="kpi-report.xls"
params=0
svrinfo=0
var1="default"
var2="default"
var3="default"
var4="default"
uri=0
filter="_(tensorflow|throughput|inference|benchmark|real)"
last_var=""
intel_publish=0
owner=""
tags=""
for var in "$@"; do
    case "$var" in
    --primary)
        primary=1
        ;;
    --svrinfo)
        svrinfo=1
        ;;
    --all)
        primary=""
        ;;
    --outlier=*)
        outlier="${var#--outlier=}"
        ;;
    --params|--params=true)
        params=1
        ;;
    --params=false)
        params=0
        ;;
    --format=*)
        format="${var#--format=}"
        ;;
    --var1=*)
        var1="${var#--var1=}"
        ;;
    --var2=*)
        var2="${var#--var2=}"
        ;;
    --var3=*)
        var3="${var#--var3=}"
        ;;
    --var4=*)
        var4="${var#--var4=}"
        ;;
    --filter=*)
        filter="${var#--filter=}"
        ;;
    --file=*)
        xlsfile="${var#--file=}"
        ;;
    --uri)
        uri=1
        ;;
    --help)
        print_help
        ;;
    --intel_publish)
        intel_publish=1
        ;;
    --owner=*)
        owner="${var#--owner=}"
        ;;
    --tags=*)
        tags="${var#--tags=}"
        ;;
    --var1|--var2|--var3|--var4|--filter|--file|--format|--outlier|--owner|--tags)
        ;;
    *)
        case "$last_var" in
        --outlier)
            outlier="$var"
            ;;
        --format)
            format="$var"
            ;;
        --var1)
            var1="$var"
            ;;
        --var2)
            var2="$var"
            ;;
        --var3)
            var3="$var"
            ;;
        --var4)
            var4="$var"
            ;;
        --filter)
            filter="$var"
            ;;
        --file)
            xlsfile="$var"
            ;;
        --owner)
            owner="$var"
            ;;
        --tags)
            tags="$var"
            ;;
        *)
            prefixes+=("$var")
            ;;
        esac
    esac
    last_var="$var"
done

if [ "$outlier" = "-1" ]; then
    outlier=0
fi

if [ "$format" != "list" ]; then
    primary=""
    params=1
fi

if [ ${#prefixes[@]} -eq 0 ]; then
    print_help
fi

if [ $intel_publish = 1 ]; then
    for logsdir1 in ${prefixes[@]}; do
        if [ -r "$logsdir1"/workload-config.yaml ]; then
            echo "Publishing $logsdir1..."
            BACKEND="$(sed -n '/^backend:/{s/.*"\(.*\)".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            BACKEND_OPTIONS="$(sed -n "/^${BACKEND}_options:/{s/.*\"\(.*\)\".*/\1/;p}" "$logsdir1"/workload-config.yaml | tr '\n' ' ') $(sed -n '/^ctestsh_options:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml | tr '\n' ' ')"
            RELEASE="$(sed -n '/^release:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            REGISTRY="$(sed -n '/^registry:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"

            if [ -r "$logsdir1"/terraform-config.tf ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --wl_categority=$(sed -n '/^\s*variable\s*"wl_categority"\s*{/,/^\s*}/{s/^\s*default\s*=\s*"\([^"]*\).*/\1/;p}' "$logsdir1"/terraform-config.tf)"
            elif [ -r "$logsdir1"/runs/*/pkb.log ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --run_uri=$(sed -n '/^--run_uri=/{s/.*=//;p}' "$logsdir1"/runs/*/pkb.log)"
            fi

            if [ -n "$owner" ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --owner=$owner"
            fi
            if [ -n "$tags" ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --tags=$tags"
            fi

            TERRAFORM_OPTIONS="$BACKEND_OPTIONS" RELEASE="$RELEASE" REGISTRY="$REGISTRY" "$DIR"/../terraform/shell.sh static -v "$(readlink -f "$logsdir1"):/opt/workspace" -- bash -c "/opt/terraform/script/publish-intel.py $BACKEND_OPTIONS < <(cat tfplan.json 2> /dev/null || echo)"
        fi
    done
fi

for logsdir1 in ${prefixes[@]}; do
    if [ -r "$logsdir1/kpi.sh" ] && [ -r "$logsdir1"/workload-config.yaml ]; then
        instv=($(
          (
            for file in "$logsdir1"/cumulus-config.yaml "$logsdir1"/runs/*/ssh_config "$logsdir1"/terraform-config.tf "$logsdir1"/inventory.yaml; do 
                [ -r "$file" ] && cat "$file"
            done 
            for file in "$logsdir1"/runs/*/*-svrinfo/*.json "$logsdir1"/*-svrinfo/*.json; do
                [ -r "$file" ] && sed 's/^/#svrinfo- /' "$file"
            done
          ) | awk -f "$DIR"/svrinfo-json.awk -f "$DIR"/svrinfo-inst.awk
        ))
        for svrinfo in "$logsdir1"/runs/*/*-svrinfo/*.json "$logsdir1"/*-svrinfo/*.json; do
            if [ -r "$svrinfo" ]; then
                echo "#svrinfo: $svrinfo ${instv[@]}"
                sed 's/^/#svrinfo- /' "$svrinfo"
                echo
            fi
        done
        script_args="$(awk '/script_args:/{$1="";print gensub(/"/,"","g")}' "$logsdir1/workload-config.yaml")"
        if [ -d "$logsdir1/itr-1" ]; then
            for itrdir1 in "$logsdir1"/itr-*; do
                echo "$itrdir1:"
                if [ $params -eq 1 ]; then
                    sed -n '/^tunables:/,/^[^ ]/{/^ /{s/^ */# /;p}}' "$logsdir1/workload-config.yaml"
                fi
                if [ -n "$primary" ]; then
                    ( cd "$itrdir1" && bash ./kpi.sh $script_args 2> /dev/null | grep -E "^\*" ) || true
                else
                    ( cd "$itrdir1" && bash ./kpi.sh $script_args 2> /dev/null ) || true
                fi
            done
        else
            echo "$logsdir1:"
            if [ $params -eq 1 ]; then
                sed -n '/^tunables:/,/^[^ ]/{/^ /{s/^ */# /;p}}' "$logsdir1/workload-config.yaml"
            fi
            if [ -n "$primary" ]; then
                ( cd "$logsdir1" && bash ./kpi.sh $script_args 2> /dev/null | grep -E "^\*" ) || true
            else
                ( cd "$logsdir1" && bash ./kpi.sh $script_args 2> /dev/null ) || true
            fi
        fi
    fi
    if [ -r "$logsdir1/publish.logs" ] && [ "$uri" -eq 1 ]; then
        sed -n '/WSF Portal URL:/{s/^[^:]*:/# portal:/;p;q}' "$logsdir1/publish.logs"
    fi
done | (
    case "$format" in
    list)
        awk -v svrinfo=$svrinfo -v outlier=$outlier -f "$DIR/kpi-list.awk" 
        ;;
    xls-ai)
        awk -v outlier=$outlier -v var1="$var1" -v var2="$var2" -v var3="$var3" -v var4="$var4" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-xls.awk" -f "$DIR/kpi-xls-ai.awk" > "$xlsfile"
        ;;
    xls-inst)
        awk -v var1="$var1" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-xls.awk" -f "$DIR/kpi-xls-inst.awk" > "$xlsfile"
        ;;
    xls-table)
        awk -v var1="$var1" -v var2="$var2" -v var3="$var3" -v var4="$var4" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-xls.awk" -f "$DIR/kpi-xls-table.awk" > "$xlsfile"
        ;;
    esac
)
