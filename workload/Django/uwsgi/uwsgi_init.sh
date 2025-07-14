#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

echo "Starting uWSGI init script on container..."

#IP_ADDR=$(grep "$1" /etc/hosts | awk '{print $1}')
IP_ADDR=$(hostname -i)

cd /django-workload/django-workload || exit 1

openssl genrsa -out django.key 2048
openssl req -new -key django.key -batch -out django.csr -subj "/" 
openssl x509 -req -days 365 -in django.csr -signkey django.key -out django.crt

if [ -f cluster_settings.py.bak ]; then
    cp -f cluster_settings.py.bak cluster_settings.py
else
    sed -e "s/DATABASES\['default'\]\['HOST'\] = 'localhost'/DATABASES\['default'\]\['HOST'\] = '$CASSANDRA_ENDPOINT'/g"                                  \
        -e "s/CACHES\['default'\]\['LOCATION'\] = '127.0.0.1:11811'/CACHES\['default'\]\['LOCATION'\] = '$MEMCACHED_ENDPOINT'/g"                          \
        -e "s/ALLOWED_HOSTS = \[/ALLOWED_HOSTS = \['$IP_ADDR','frontend', /g" \
        -i cluster_settings.py
    #PROC_NO=$(grep -c processor /proc/cpuinfo)
    sed -i "s/processes = 88/processes = $PROC_NO/g" uwsgi.ini
    sed -i '$ a listen = 1024' uwsgi.ini
    cp cluster_settings.py cluster_settings.py.bak
fi
if [ "$TLSVERSION" == "TLSv1.2" ]; then
    sed -i '$ a ssl-option = 536870912' uwsgi.ini
fi
if [ "$TLS" == "1" ]; then
    sed -i "s/^http = .*//g" uwsgi.ini
    sed -i '$ a https-socket = %(hostname),django.crt,django.key' uwsgi.ini
fi

sed -i "/middleware.SessionMiddleware/c\'django.contrib.sessions.middleware.SessionMiddleware'," django_workload/settings.py
sed -i "/middleware.MessageMiddleware/c\'django.contrib.messages.middleware.MessageMiddleware'," django_workload/settings.py
sed -i "/middleware.AuthenticationMiddleware/c\'django.contrib.auth.middleware.AuthenticationMiddleware'," django_workload/settings.py
sed -i "s/cluster_settings/django_workload.cluster_settings/g" uwsgi.ini

sysctl -p
. venv/bin/activate
cp -f cluster_settings.py django_workload/cluster_settings.py
DJANGO_SETTINGS_MODULE=django_workload.cluster_settings django-admin setup &> django-admin.log

uwsgi uwsgi.ini &

deactivate

tail -f /dev/null

