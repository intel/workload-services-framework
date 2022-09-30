#!/bin/bash -e

DIR="$(dirname "$(readlink -f "$0")")"

print_help () {
    echo "Usage: [options] logsdir"
    echo "--primary             List only the primary KPI."
    echo "--all                 List all KPIs."
    echo "--params              Print out all configuration parameters."
    echo "--outlier <n>         Drop samples beyond N-stdev."
    echo "--format <format>     Specify the output format: list, xls-ai, xls-inst, or xls-table."
    echo "--var[1-9] value      Specify spreadsheet variables."
    echo "--phost name          Specify the primary hostname for identifying instance type."
    echo "--pinst name          Specify the svrinfo field for identifying instance type name."
    echo "--file filename       Specify the spreadsheet filename."
    echo "--filter filter       Specify the trim filter to shorten the worksheet name."
    exit 0
}

phost="node1"
pinst="System.Product Name"
prefixes=()
primary=1
outlier=0
printvar=0
format="list"
xlsfile="kpi-report.xls"
params=0
var1="default"
var2="default"
var3="default"
var4="default"
filter="_(tensorflow|throughput|inference|benchmark|real)"
for var in "$@"; do
    case "$var" in
    --primary)
        primary=1
        ;;
    --all)
        primary=""
        ;;
    --outlier=*)
        outlier="${var#--outlier=}"
        ;;
    --outlier)
        outlier="-1"
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
    --format)
        format="-1"
        ;;
    --var1=*)
        var1="${var#--var1=}"
        ;;
    --var1)
        var1="-1"
        ;;
    --var2=*)
        var2="${var#--var2=}"
        ;;
    --var2)
        var2="-1"
        ;;
    --var3=*)
        var3="${var#--var3=}"
        ;;
    --var3)
        var3="-1"
        ;;
    --var4=*)
        var4="${var#--var4=}"
        ;;
    --var4)
        var4="-1"
        ;;
    --phost=*)
        phost="${var#--phost=}"
        ;;
    --phost)
        phost="-1"
        ;;
    --pinst=*)
        pinst="${var#--pinst=}"
        ;;
    --pinst)
        pinst="-1"
        ;;
    --filter=*)
        filter="${var#--filter=}"
        ;;
    --filter)
        filter="-1"
        ;;
    --file=*)
        xlsfile="${var#--file=}"
        ;;
    --file)
        xlsfile=""
        ;;
    --help)
        print_help
        ;;
    *)
        if [ "$outlier" = "-1" ]; then
            outlier="$var"
        elif [ "$format" = "-1" ]; then
            format="$var"
        elif [ "$var1" = "-1" ]; then
            var1="$var"
        elif [ "$var2" = "-1" ]; then
            var2="$var"
        elif [ "$var3" = "-1" ]; then
            var3="$var"
        elif [ "$var4" = "-1" ]; then
            var4="$var"
        elif [ "$phost" = "-1" ]; then
            phost="$var"
        elif [ "$pinst" = "-1" ]; then
            pinst="$var"
        elif [ "$filter" = "-1" ]; then
            filter="$var"
        elif [ -z "$xlsfile" ]; then
            xlsfile="$var"
        else
            prefixes+=("$var")
        fi
        ;;
    esac
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

for logsdir1 in ${prefixes[@]}; do
    if [ -r "$logsdir1/kpi.sh" ] && [ -r "$logsdir1"/cumulus-config.yaml ]; then
        pinstv=""
        for svrinfo in "$logsdir1"/runs/*/pkb-*-svrinfo/*.json; do
            if [ -r "$svrinfo" ]; then
                pinstv="$(sed 's/^/#svrinfo- /' "$logsdir1"/runs/*/pkb-*-svrinfo/*.json | awk -v name=$phost -v pinst="$pinst" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-inst.awk")"
                break
            fi
        done
        for svrinfo in "$logsdir1"/runs/*/pkb-*-svrinfo/*.json; do
            if [ -r "$svrinfo" ]; then
                echo "#svrinfo: $svrinfo $pinstv"
                sed 's/^/#svrinfo- /' "$svrinfo"
                echo
            fi
        done
        script_args="$(awk '/dpt_script_args:/{$1="";print gensub(/"/,"","g")}' "$logsdir1/cumulus-config.yaml")"
        if [ -d "$logsdir1/itr-1" ]; then
            for itrdir1 in "$logsdir1"/itr-*; do
                echo "$itrdir1:"
                if [ $params -eq 1 ]; then
                    awk '/dpt_tunables:/{$1="";print gensub(/"/,"","g")}' "$logsdir1/cumulus-config.yaml" | tr ';' '\n' | sed 's/^ *\([^:]*\):\(.*\)$/# \1: "\2"/'
                fi
                chmod a+rx "$itrdir1/kpi.sh"
                if [ -n "$primary" ]; then
                    ( cd "$itrdir1" && ./kpi.sh $script_args | grep -E "^\*" ) || true
                else
                    ( cd "$itrdir1" && ./kpi.sh $script_args ) || true
                fi
            done
        else
            echo "$logsdir1:"
            if [ $params -eq 1 ]; then
                awk '/dpt_tunables:/{$1="";print gensub(/"/,"","g")}' "$logsdir1/cumulus-config.yaml" | tr ';' '\n' | sed 's/^ *\([^:]*\):\(.*\)$/# \1: "\2"/'
            fi
            chmod a+rx "$logsdir1/kpi.sh"
            if [ -n "$primary" ]; then
                ( cd "$logsdir1" && ./kpi.sh $script_args | grep -E "^\*" ) || true
            else
                ( cd "$logsdir1" && ./kpi.sh $script_args ) || true
            fi
        fi
    elif [ -r "$logsdir1/kpi.sh" ] && [ -r "$logsdir1"/workload-config.yaml ]; then
        script_args="$(awk '/^script_args:/{$1="";print gensub(/"/,"","g")}' "$logsdir1/workload-config.yaml")"
        echo "$logsdir1:"
        if [ $params -eq 1 ]; then
            awk '/^tunables:/{$1="";print gensub(/"/,"","g")}' "$logsdir1/workload-config.yaml" | tr ';' '\n' | sed 's/^ *\([^:]*\):\(.*\)$/# \1: "\2"/'
        fi
        chmod a+rx "$logsdir1/kpi.sh"
        if [ -n "$primary" ]; then
            ( cd "$logsdir1" && ./kpi.sh $script_args | grep -E "^\*" ) || true
        else
            ( cd "$logsdir1" && ./kpi.sh $script_args ) || true
        fi
    fi
done | (
    case "$format" in
    list)
        awk -v outlier=$outlier -f "$DIR/kpi-list.awk" 
        ;;
    xls-ai)
        awk -v outlier=$outlier -v var1="$var1" -v var2="$var2" -v var3="$var3" -v var4="$var4" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-xls.awk" -f "$DIR/kpi-xls-ai.awk" > "$xlsfile"
        ;;
    xls-inst)
        awk -v var1="$var1" -v phost=$phost -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-xls.awk" -f "$DIR/kpi-xls-inst.awk" > "$xlsfile"
        ;;
    xls-table)
        awk -v var1="$var1" -v var2="$var2" -v var3="$var3" -v var4="$var4" -v filter="$filter" -f "$DIR/xlsutil.awk" -f "$DIR/svrinfo-json.awk" -f "$DIR/svrinfo-xls.awk" -f "$DIR/kpi-xls-table.awk" > "$xlsfile"
        ;;
    esac
)
