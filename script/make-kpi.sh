#!/bin/bash -e

script_args () {
    awk '
    /script_args:/ {
        $1=""
        print gensub(/"/,"","g")
    }' "$1"
}

for itr in "$1"/itr-*; do 
    if [ -x $itr/kpi.sh ] && [ -r $itr/../cumulus-config.yaml ]; then 
        (
            cd $itr
            echo "# $itr" 
            ./kpi.sh $(script_args ../cumulus-config.yaml) || true
        )
    fi
done

if [ -x "$1"/kpi.sh ] && [ -r "$1"/workload-config.yaml ]; then 
    cd "$1"
    ./kpi.sh $(script_args workload-config.yaml) || true
fi
