#!/bin/bash -e

if [ -n "$DOCKER_GID" ]; then
    if grep -q -E '^docker:' /etc/group; then
        if [ "$DOCKER_GID" != "$(getent group docker | cut -f3 -d:)" ]; then
            groupmod -g $DOCKER_GID -o docker > /dev/null || true
        fi
    fi
fi

if [ -n "$PKB_GID" ]; then
    if [ "$PKB_GID" != "$(id -g pkb)" ]; then
        groupmod -g $PKB_GID -o pkb > /dev/null || true
    fi
    if [ -n "$PKB_UID" ]; then
        if [ "$PKB_UID" != "$(id -u pkb)" ]; then
            usermod -u $PKB_UID -g $PKB_GID -o pkb > /dev/null || true
        fi
    fi
fi

####INSERT####
exec gosu pkb "$@"
