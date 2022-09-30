#!/bin/bash -e

registry_id=${1%.dkr.ecr.*}
region=${1%.amazonaws.com/*}
region=${region/*dkr.ecr./}
repository_name=${1#*.amazonaws.com/}
repository_name=${repository_name%:*}

if [[ "$(aws ecr describe-repositories --region $region)" != *"\"$repository_name\""* ]]; then
    aws ecr create-repository --registry-id $registry_id --repository-name $repository_name --region $region > /dev/null
fi
