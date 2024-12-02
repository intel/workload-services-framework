#!/bin/bash

/etc/eks/bootstrap.sh ${cluster_name} --b64-cluster-ca ${certificate_data} --apiserver-endpoint ${cluster_endpoint} --dns-cluster-ip ${dns_cluster_ip}

