#!/bin/bash -e

# overwrite this file to provide customized provisioning of the cumulus cluster 
# tailed to the workload provisioning requests. The default is to use what is
# specified in script/cumulus/cumulus-config.yaml

# args: [in] cluster-config [out] cumulus-config.yaml [in] docker/kubernetes

if [ -z "$(grep cloud: "$CUMULUS_CONFIG_IN")" ]; then
    cp -f "$CUMULUS_CONFIG_IN" "$2"
else
    nworkers=$(grep labels "$1" | wc -l)
    if [ -n "$NWORKERS_MAX" ] && [ "$nworkers" -gt "$NWORKERS_MAX" ]; then
        nworkers="$NWORKERS_MAX"
    fi
    disk_spec="$(awk -v ds="" '
/HAS-SETUP-DISK-/ {
    ds=gensub(/.*DISK-(.*)-(.*):.*/,"disk_\\1_\\2",1)
}
END {
    print tolower(ds)
}' "$1")"

    if [ "$3" = "docker" ]; then
        # remove the controller group in the docker mode
        awk '
/^.*#.*/ {
    print
    next
}
/^ *controller: *$/ {
    n=index($0,$1)
    next
}
n>0 && index($0,$1)>n {
    next
}
{
    print
    n=0
}' "$CUMULUS_CONFIG_IN"
    else
        cat "$CUMULUS_CONFIG_IN"
    fi | awk -v n=$nworkers '
/^\s*worker:\s*$/ {
    w=1
}
{
    if ($1=="vm_count:"&&w==1&&n>$2) {
        print gensub(/:.*/,": "n,1)
        w=0
    } else {
        print
    }
}
' > "$2"

    # adjust the SKU instance type
    eval "machine_type=\"\$$(awk '/cloud:/{print toupper($NF)}' "$2"|tr -d '" ')_MACHINE_TYPE\""
    if [ -n "$machine_type" ]; then
        sed -i "1,/machine_type:/s/machine_type:.*/machine_type: $machine_type/" "$2"
    fi
    if [ -n "$disk_spec" ]; then
        echo "disk_spec=$disk_spec"
        sed -i "1,/disk_spec:/s/disk_spec: *\([^_]*\)_.*/disk_spec: \\1_$disk_spec/" "$2"
    else
        sed -i "1,/disk_spec:/s/\(disk_spec:.*\)/#\\1/" "$2"
    fi
    # expose disk_type parameter, e.g: ./ctest.sh --set AZURE_DISK_TYPE=Premium_LRS
    eval "disk_type=\"\$$(awk '/cloud:/{print toupper($NF)}' "$2"|tr -d '" ')_DISK_TYPE\""
    if [ -n "$disk_type" ]; then
        sed -i "1,/disk_type:/s/disk_type:.*/disk_type: $disk_type/" "$2"
    fi
fi

# docker_auth_reuse
[ "$REGISTRY_AUTH" = "docker" ] && [ -n "$(grep auths "$HOME/.docker/config.json" 2> /dev/null)" ] && auth_reuse=true || auth_reuse=false
sed -i -e '/docker_auth_reuse:.*/d' -e "s/^\(\s*\)\(dpt_namespace:.*\)$/\1\2\n\1docker_auth_reuse: $auth_reuse/" "$2"

