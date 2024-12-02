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
    echo "--sutinfo             Print out sutinfo."
    echo "--outlier <n>         Drop samples beyond N-stdev."
    echo "--format <format>     Specify the output format: list, xls-ai, xls-inst, or xls-table."
    echo "--var[1-9] value      Specify spreadsheet variables."
    echo "--file filename       Specify the spreadsheet filename."
    echo "--filter filter       Specify the trim filter to shorten the worksheet name."
    echo "--uri                 Show WSF portal URI."
    echo "--intel_publish       Publish logs to the WSF dashboard."
    echo "--export-trace        Re-run the trace export routines."
    echo "--owner <name>        Set publisher owner."
    echo "--tags <tags>         Set publisher tags."
    echo "--pretag <pretag>     Set data-quality tag."
    echo "--recent              List KPIs for recent testcase logs."
    exit 0
}

get_status_code () {
  local status_ret=1
  local status_value=0
  for status_path in "$1"/*/status; do
      if [ -e "$status_path" ]; then
          status_value="$(< "$status_path")"
          [ "$status_value" -eq 0 ] || return 1
          status_ret=0
      fi
  done
  return $status_ret
}

get_recent_logs () {
  DIRPATH="$(pwd)"
  while [[ "$DIRPATH" = */* ]]; do
    if [ -r "$DIRPATH/.log_files" ]; then
      cat "$DIRPATH/.log_files" | sort | uniq
      break
    fi
    DIRPATH="${DIRPATH%/*}"
  done
}

prefixes=()
primary=1
outlier=0
printvar=0
format="list"
xlsfile="kpi-report.xls"
params=0
sutinfo=0
var1="default"
var2="default"
var3="default"
var4="default"
uri=0
filter="_(tensorflow|throughput|inference|benchmark|real)"
last_var=""
intel_publish=0
trace_export=0
owner=""
tags=""
pretag=""
for var in "$@"; do
    case "$var" in
    --primary)
        primary=1
        ;;
    --sutinfo|--svrinfo)
        sutinfo=1
        ;;
    --all)
        primary=0
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
    --export-trace)
        trace_export=1
        ;;
    --owner=*)
        owner="${var#--owner=}"
        ;;
    --tags=*)
        tags="${var#--tags=}"
        ;;
    --pretag=*)
        pretag="${var#--pretag=}"
        ;;
    --var1|--var2|--var3|--var4|--filter|--file|--format|--outlier|--owner|--tags|--pretag)
        ;;
    --recent)
        IFS=$'\n' prefixes+=($(get_recent_logs))
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
        --pretag)
            pretag="$var"
            ;;
        *)
            prefixes+=("${var%/}")
            ;;
        esac
    esac
    last_var="$var"
done

if [ "$outlier" = "-1" ]; then
    outlier=0
fi

if [ "$format" != "list" ]; then
    primary=0
    params=1
fi

if [ ${#prefixes[@]} -eq 0 ]; then
    print_help
fi

if [ $trace_export = 1 ]; then
    for logsdir1 in "${prefixes[@]}"; do
        if [ -r "$logsdir1"/workload-config.yaml ]; then
            echo "Export trace data from $logsdir1..."
            RELEASE="$(sed -n '/^release:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            REGISTRY="$(sed -n '/^registry:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            BACKEND="$(sed -n '/^backend:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            csp="$(grep -E '^\s*csp\s*=' "$logsdir1/terraform-config.tf" | cut -f2 -d'"' | tail -n1)"
            ansible_options=()
            for v in $(sed -n "/^${BACKEND}_options:/{s/.*\"\(.*\)\".*/\1/;p}" "$logsdir1"/workload-config.yaml | tr '\n' ' ') $(sed -n '/^ctestsh_options:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml | tr '\n' ' '); do
                k1="$(echo "${v#--}" | cut -f1 -d=)"
                v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
                case "$v" in
                --*=*)
                    ansible_options+=("-e" "$k1='$v1'")
                    ;;
                --no*)
                    ansible_options+=("-e" "${k1#no}=false")
                    ;;
                --*)
                    ansible_options+=("-e" "$k1=true")
                    ;;
                esac
            done
            RELEASE="$RELEASE" REGISTRY="$REGISTRY" "$DIR"/../terraform/shell.sh ${csp:-static} -v "$(readlink -f "$logsdir1"):/opt/workspace" -- bash -c "ANSIBLE_ROLES_PATH=/opt/terraform/template/ansible/traces/roles:/opt/terraform/template/ansible/common ANSIBLE_CONFIG=/opt/terraform/template/ansible/ansible.cfg ANSIBLE_INVENTORY_ENABLED=host_list ansible-playbook ${ansible_options[*]} -vv -c local -i 127.0.0.1, -e wl_logs_dir=/opt/workspace /opt/terraform/template/ansible/common/export.yaml"
        fi
    done
fi

if [ $intel_publish = 1 ]; then
    for logsdir1 in "${prefixes[@]}"; do
        if [ -r "$logsdir1"/workload-config.yaml ]; then
            echo "Publishing $logsdir1..."
            BACKEND="$(sed -n '/^backend:/{s/.*"\(.*\)".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            BACKEND_OPTIONS="$(sed -n "/^${BACKEND}_options:/{s/.*\"\(.*\)\".*/\1/;p}" "$logsdir1"/workload-config.yaml | tr '\n' ' ') $(sed -n '/^ctestsh_options:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml | tr '\n' ' ')"
            RELEASE="$(sed -n '/^release:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            REGISTRY="$(sed -n '/^registry:/{s/.*\"\(.*\)\".*/\1/;p}' "$logsdir1"/workload-config.yaml)"
            csp="$(grep -E '^\s*csp\s*=' "$logsdir1/terraform-config.tf" | cut -f2 -d'"' | tail -n1)"

            if [ -r "$logsdir1"/terraform-config.tf ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --wl_categority=$(sed -n '/^\s*variable\s*"wl_categority"\s*{/,/^\s*}/{s/^\s*default\s*=\s*"\([^"]*\).*/\1/;p}' "$logsdir1"/terraform-config.tf)"
            fi

            if [ -n "$owner" ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --owner=$owner"
            fi
            if [ -n "$tags" ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --tags=$tags"
            fi
            if [ -n "$pretag" ]; then
                BACKEND_OPTIONS="$BACKEND_OPTIONS --pretag=$pretag"
            fi

            TERRAFORM_OPTIONS="$BACKEND_OPTIONS" RELEASE="$RELEASE" REGISTRY="$REGISTRY" "$DIR"/../terraform/shell.sh ${csp:-static} -v "$(readlink -f "$logsdir1"):/opt/workspace" -- bash -c "/opt/terraform/script/publish-intel.py $BACKEND_OPTIONS < <(cat tfplan.json 2> /dev/null || cat .tfplan.json 2> /dev/null || echo)" | tee "$logsdir1/publish.logs"
        fi
    done
fi

for logsdir1 in "${prefixes[@]}"; do
    if [ -r "$logsdir1/kpi.sh" ] && [ -r "$logsdir1"/workload-config.yaml ]; then
        instv=($(
          (
            for file in "$logsdir1"/terraform-config.tf "$logsdir1"/inventory.yaml; do 
                [ -r "$file" ] && cat "$file"
            done 
            for file in "$logsdir1"/*-sutinfo/*.json "$logsdir1"/*-svrinfo/*.json; do
                [ -r "$file" ] && sed 's/^/#sutinfo- /' "$file"
            done
          ) | awk -f "$DIR"/sutinfo-json.awk -f "$DIR"/sutinfo-inst.awk
        ))
        for sutinfo in "$logsdir1"/*-sutinfo/*.json "$logsdir1"/*-svrinfo/*.json; do
            if [ -r "$sutinfo" ]; then
                echo "#sutinfo: $sutinfo ${instv[@]}"
                sed 's/^/#sutinfo- /' "$sutinfo"
                echo
            fi
        done
        for power in "$logsdir1"/*-pcm/roi-*/power.records; do
            if [ -r "$power" ]; then
                echo "#pcm: $(echo "$power" | sed 's|^.*/\([^/]*\)-pcm/.*$|\1|') $(echo "$power" | sed 's|^.*/\(roi-[0-9]*\)/.*$|\1|')"
                sed 's/^/#pcm- /' "$power"
            fi
        done
        for power in "$logsdir1"/*-pdu/pdu-*.logs; do
            if [ -r "$power" ]; then
                echo "#pdu: $(echo "$power" | sed 's|^.*/\([^/]*\)-pdu/.*$|\1|') $(echo "$power" | sed 's|^.*/pdu-\([0-9]*\).logs$|roi-\1|')"
                sed 's/^/#pdu- /' "$power"
            fi
        done
        for power in "$logsdir1"/*-uprof/roi-*/timechart.csv; do
            if [ -r "$power" ]; then
                echo "#uprof: $(echo "$power" | sed 's|^.*/\([^/]*\)-uprof/.*$|\1|') $(echo "$power" | sed 's|^.*/\(roi-[0-9]*\).*$|\1|')"
                sed 's/^/#uprof- /' "$power"
            fi
        done
        for power in "$logsdir1"/*-emon/emon-*-edp/__mpp_socket_view_details.csv; do
            if [ -r "$power" ]; then
                echo "#emon: $(echo "$power" | sed 's|^.*/\([^/]*\)-emon/.*$|\1|') $(echo "$power" | sed 's|^.*/emon-\([0-9]*\)-edp/.*$|roi-\1|')"
                sed 's/^/#emon- /' "$power"
            fi
        done
        for power in "$logsdir1"/*-perfspect/roi-*/*_metrics.csv; do
            if [ -r "$power" ]; then
                echo "#perfspect: $(echo "$power" | sed 's|^.*/\([^/]*\)-perfspect/.*$|\1|') $(echo "$power" | sed 's|^.*/\(roi-[0-9]*\)/.*$|\1|')"
                sed 's/^/#perfspect- /' "$power"
            fi
        done
        script_args="$(sed -n '/^script_args:/{s/script_args: "\(.*\)"$/\1/;p}' "$logsdir1/workload-config.yaml")"
        if [ -d "$logsdir1/itr-1" ]; then
            for itrdir1 in "$logsdir1"/itr-*; do
                echo "$(readlink -f "$itrdir1" | sed -e 's|.*/workload/|workload/|' -e 's|.*/stack/|stack/|' -e 's|.*/image/|image/|'):"
                if get_status_code "$itrdir1"; then
                    echo "# status: passed"
                else
                    echo "# status: failed"
                fi
                (
                    sed -n '/^tunables:/,/^[^ ]/{/^ /{s/^ */## /;p}}' "$logsdir1/workload-config.yaml"
                    cd "$itrdir1"
                    bash ./kpi.sh $script_args
                ) 2> /dev/null | awk -v pr=$primary -v pm=$params '
                BEGIN {
                    split("",kpis_u)
                }
                /^## [^: ]*: / {
                    k=gensub(/^## ([^: ]*):.*/,"\\1",1)
                    v=gensub(/["]/,"","g",gensub(/^## [^: ]*: /,"",1))
                    if (k!="testcase") params[k]=v
                    next
                }
                /^#/ {
                    next
                }
                /^[^:]*: / {
                    k=gensub(/^([^:]*):.*/,"\\1",1)
                    v=gensub(/["]/,"","g",gensub(/^[^:]*: /,"",1))
                    if (k in kpis_u) {
                        j=kpis_u[k]
                    } else {
                        kpis_u[k]=j=length(kpis_u)+1
                    }
                    kpis_k[j]=k
                    kpis_v[j]=v
                }
                END {
                    if (pm)
                      for (k in params)
                        print "# "k": "params[k]
                    for (i=1;i<=length(kpis_k);i++) {
                      if (pr==0 || index(kpis_k[i],"*")==1)
                        print kpis_k[i]": "kpis_v[i]
                    }
                }' || true
            done
        else
            echo "$logsdir1:"
            echo "# status: failed"
        fi
        sed -n '/^bom:/,/^[^ ][^ ]/{/^  /{s/^  /#bom- /;p}}' "$logsdir1"/workload-config.yaml 
    else
        echo "$logsdir1:"
        echo "# status: failed"
    fi
    if [ -r "$logsdir1/publish.logs" ] && [ "$uri" -eq 1 ]; then
        sed -n '/WSF Portal URL:/{s/^[^:]*:/# portal:/;p;q}' "$logsdir1/publish.logs"
    fi
done | (
    case "$format" in
    list)
        awk -v sutinfo=$sutinfo -v outlier=$outlier -f "$DIR/kpi-list.awk" 
        ;;
    xls-list)
        awk -f "$DIR/xlsutil.awk" -f "$DIR/sutinfo-json.awk" -f "$DIR/sutinfo-xls.awk" -f "$DIR/kpi-xls-list.awk" > "$xlsfile"
        ;;
    xls-ai)
        awk -v outlier=$outlier -v var1="$var1" -v var2="$var2" -v var3="$var3" -v var4="$var4" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/sutinfo-json.awk" -f "$DIR/sutinfo-xls.awk" -f "$DIR/kpi-xls-ai.awk" > "$xlsfile"
        ;;
    xls-inst)
        awk -v var1="$var1" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/sutinfo-json.awk" -f "$DIR/sutinfo-xls.awk" -f "$DIR/kpi-xls-inst.awk" > "$xlsfile"
        ;;
    xls-table)
        awk -v var1="$var1" -v var2="$var2" -v var3="$var3" -v var4="$var4" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/sutinfo-json.awk" -f "$DIR/sutinfo-xls.awk" -f "$DIR/kpi-xls-table.awk" > "$xlsfile"
        ;;
    esac
)
