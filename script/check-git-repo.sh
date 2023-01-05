#!/bin/bash -e

if [ ${#@} -lt 1 ]; then
    echo "Usage: <cache-file> repo ..."
fi

check_access () {
    GIT_ASKPASS=echo timeout 5 git ls-remote --exit-code "$1" > /dev/null 2>&1
}

check_history () {
    grep -qFx "$1" "$2" 2> /dev/null
}

cache="$1" 
shift
for repo in ${@}; do
    echo -n "Checking $repo..."
    if check_history "$repo" "$cache"; then
        access=OK
    elif check_access "$repo"; then
        access=OK
        echo "$repo" >> "$cache"
    else
        access=denied
    fi
    if [ $access = OK ]; then
        echo "OK"
    else
        echo "denied"
        echo
        echo "Please apply for repository access. Build aborted."
        echo
        exit 1
    fi
done
exit 0
