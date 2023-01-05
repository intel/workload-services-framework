#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: [options] <host>[:port]"
  echo "<host> can be in the form of a FQDN hostname or an IP address."
  echo "--mirror=<url>   Launch the registry as a pull-through cache registry."
  echo "The default port value for a docker registry is 20666."
  echo "The default port value for a pull-through cache is 20690."
  exit 3
fi

port=""
mirror_url=""
last=""
for v in $@; do
  case "$v" in
  --mirror=*)
    mirror_url="${v#--mirror=}"
    ;;
  --mirror)
    ;;
  *)
    if [ "$last" = "--mirror" ]; then
      mirror_url="$v"
    else
      host="${v/:*/}"
      [[ "$v" = *":"* ]] && port="${v/*:/}"
    fi
    ;;
  esac
  last="$v"
done

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"

./setup-ansible.sh
if [ -z "$mirror_url" ]; then
  [[ -z "$port" ]] && port=20666
  ansible-playbook -vvvv --inventory 127.0.0.1, -e ansible_user="$(id -un)" -e dev_cert_host=$host -e dev_registry_port=$port -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 -K ./setup-reg.yaml
else
  [[ "$mirror_url" != "http"* ]] && mirror_url="https://$mirror_url"
  [[ -z "$port" ]] && port=20690
  ansible-playbook -vvvv --inventory 127.0.0.1, -e ansible_user="$(id -un)" -e dev_cert_host=$host -e dev_registry_port=$port -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 -e dev_registry_name=dev-cache -e dev_registry_mirror=$mirror_url -K ./setup-reg.yaml
fi
