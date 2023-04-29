#!/bin/bash

scan_vpc_dhcp_option () {
    echo
    echo "Scanning vpc dhcp options..."
    for dhcp in $(aws --region $region ec2 describe-vpcs --filters Name=vpc-id,Values=$1 | awk '/"DhcpOptionsId":/{print$NF}' | tr -d '",'); do
        if [ "$dhcp" != "default" ]; then
            echo "DHCP Option: $dhcp"
            resources+=($dhcp)
            (set -x; aws ec2 --region ${region} associate-dhcp-options --dhcp-options-id default --vpc-id $vpc)
            (set -x; aws ec2 --region ${region} delete-dhcp-options --dhcp-options-id ${dhcp})
        fi
    done
}

scan_vpc_internet_gateway () {
    echo
    echo "Scanning vpc internet-gateways..."
    for gateway in $(aws --region $region ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$1 | awk '/"InternetGatewayId":/{print$NF}' | tr -d '",'); do
        echo "InternetGateway: $gateway"
        resources+=($gateway)
        (set -x; aws ec2 --region ${region} detach-internet-gateway --internet-gateway-id ${gateway} --vpc-id $vpc)
    done
}

scan_vpc_nat_gateway () {
    echo
    echo "Scanning vpc nat gateways..."
    for gateway in $(aws --region $region ec2 describe-nat-gateways --filter Name=vpc-id,Values=$1 | awk '/"NatGatewayId":/{print$NF}' | tr -d '",'); do
        echo "NAT Gateway: $gateway"
        resources+=($gateway)
        (set -x; aws ec2 --region ${region} detach-nat-gateway --nat-gateway-id ${gateway} --vpc-id $vpc)
    done
}

scan_vpc_vpn_connection () {
    echo
    echo "Scanning vpc vpn connections..."
    for con in $(aws --region $region ec2 describe-vpn-connections --filters Name=vpc-id,Values=$1 | awk '/"VpnConnectionId":/{print$NF}' | tr -d '",'); do
        echo "VPN Connection: $con"
        resources+=($con)
        (set -x; aws ec2 --region ${region} detach-vpn-connection --vpn-connection-id ${con} --vpc-id $vpc)
    done
}

scan_vpc_vpn_gateway () {
    echo
    echo "Scanning vpc vpn gateways..."
    for gateway in $(aws --region $region ec2 describe-vpn-gateways --filters Name=vpc-id,Values=$1 | awk '/"VpnGatewayId":/{print$NF}' | tr -d '",'); do
        echo "VPN Gateway: $gateway"
        resources+=($gateway)
        (set -x; aws ec2 --region ${region} detach-vpn-gateway --vpn-getway-id ${gateway} --vpc-id $vpc)
    done
}

scan_vpc_peering_connection () {
    echo
    echo "Scanning vpc peering connections..."
    for vpcp in $(aws --region $region ec2 describe-vpc-peering-connections --filters Name=requester-vpc-info.vpc-id,Values=$1 | awk '/"VpcP":/{print$NF}' | tr -d '",'); do
        echo "Peering Connection: $vpcp"
        resources+=($vpcp)
        (set -x; aws ec2 --region ${region} delete-vpc-peering-connection --vpc-peering-connection-id ${vpcp})
    done
}

scan_vpc_network_interface () {
    echo
    echo "Scanning vpc network interfaces..."
    for netinf in $(aws --region $region ec2 describe-network-interfaces --output=json --filters Name=vpc-id,Values=$1 | awk '/"AttachmentId":/{at=$NF}/"NetworkInterfaceId":/{print$NF":"at}' | tr -d '",'); do
        echo "VPC: $vpc, NetworkInterface: $netinf"
        resources+=($netinf)
        [ -n "${netinf/*:/}" ] && (set -x; aws ec2 --region ${region} detach-network-interface --attachment-id ${netinf/*:/} --force)
        (set -x; aws ec2 --region ${region} delete-network-interface --network-interface-id ${netinf/:*/})
    done
}
  
scan_vpc_security_group () {
    echo
    echo "Scanning vpc security groups..."
    for sg in $(aws --region $region ec2 describe-security-groups --output=json --filters Name=vpc-id,Values=$1 | awk '/"GroupId":/{print$NF}' | tr -d '",'); do
        echo "SecurityGroup: $sg"
        resources+=($sg)
        (set -x; aws ec2 --region=$region delete-security-group --group-id $sg)
    done
}
  
scan_vpc_route_table () {
    echo
    echo "Scanning vpc route tables..."
    for rt in $(aws --region $region ec2 describe-route-tables --output=json --filters Name=vpc-id,Values=$1 | awk '/"RouteTableId":/{print$NF}' | tr -d '",'); do
        echo "RouteTable: $rt"
        resources+=($rt)

        for cidr in $(aws --region $region ec2 describe-route-tables --output=json --filters Name=vpc-id,Values=$1 | awk '/"DestinationCidrBlock":/{print$NF}' | tr -d '",'); do
            echo "CIDR: $cidr"
            (set -x; aws ec2 --region=$region delete-route --route-table-id $rt --destination-cidr-block $cidr)
        done
        (set -x; aws ec2 --region=$region delete-route-table --route-table-id $rt)
    done
}

scan_vpc_volume () {
    echo
    echo "Scanning vpc volumes..."
    for vol in $(aws --region $region ec2 describe-volumes --output=json --filters Name=attachment.instance-id,Values=$1 | awk '/"VolumeId":/{print$NF}' | tr -d '",'); do
        echo "Volume: $vol"
        resources+=($vol)
        (set -x; aws ec2 --region=$region detach-volume --volume-id $vol --instance-id $vpc --force)
        (set -x; aws ec2 --region=$region delete-volume --volume-id $vol)
    done
}

scan_vpc_subnet () {
    echo
    echo "Scanning vpc subnets..."
    for sid in $(aws --region $region ec2 describe-subnets --output=json --filters Name=vpc-id,Values=$1 | awk '/"SubnetId":/{print$NF}' | tr -d '",'); do
        echo "Subnet: $sid"
        resources+=($sid)
        (set -x; aws ec2 --region=$region delete-subnet --subnet-id $sid)
    done
}

scan_vpc_instance () {
    echo
    echo "Scanning vpc instances..."
    for iid in $(aws --region $region ec2 describe-instances --output=json --filters Name=vpc-id,Values=$1 | awk '/"InstanceId":/{print$NF}' | tr -d '",'); do
        if [ -z "$(aws --region $region ec2 describe-instances --output=json --filters Name=instance-id,Values=$iid | grep "\"Name\": \"terminated\"")" ]; then
            echo "Instance: $iid"
            resources+=($iid)
            (set -x; aws ec2 --region=$region terminate-instances --instance-id $iid)
        fi
    done
}

scan_vpc_network_acl () {
    echo
    echo "Scanning vpc network ACL..."
    for acl in $(aws --region $region ec2 describe-network-acls --output=json --filters Name=vpc-id,Values=$1 | awk '/"NetworkAclId":/{print$NF}' | tr -d '",'); do
        echo "Network ACL: $acl"
        resources+=($acl)
        (set -x; aws ec2 --region ${region} delete-network-acl --network-acl-id $acl)
    done
}

scan_vpc_endpoint () {
    echo
    echo "Scanning vpc endpoint..."
    for vpce in $(aws --region $region ec2 describe-vpc-endpoints --output=json --filters Name=vpc-id,Values=$1 | awk '/"VpcEndpointId":/{print$NF}' | tr -d '",'); do
        echo "VPC Endpoint: $vpce"
        resources+=($vpce)
        (set -x; aws ec2 --region ${region} delete-vpc-endpoint --vpc-endpoint-id $vpce)
    done
}

scan_placement_group () {
    echo
    echo "Scanning placement groups..."
    for pgn in $(aws --region $region ec2 describe-placement-groups --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"GroupName":/{print$NF}' | tr -d '",'); do
        echo "Placement group: $pgn"
        resources+=($pgn)
        (set -x; aws ec2 --region=$region delete-placement-group --group-name $pgn)
    done
}
  
scan_internet_gateway () {
    echo
    echo "Scanning internet-gateways..."
    for gateway in $(aws --region $region ec2 describe-internet-gateways --filters Name=tag:owner,Values="$OWNER" | awk '/"InternetGatewayId":/{print$NF}' | tr -d '",'); do
        echo "InternetGateway: $gateway"
        resources+=($gateway)
        (set -x; aws ec2 --region ${region} delete-internet-gateway --internet-gateway-id ${gateway})
    done
}
  
scan_subnet () {
    echo
    echo "Scanning subnets..."
    for subnet in $(aws --region $region ec2 describe-subnets --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"SubnetId":/{print$NF}' | tr -d '",'); do
        echo "Subnet: $subnet"
        resources+=($subnet)
        (set -x; aws ec2 --region ${region} delete-subnet --subnet-id $subnet)
    done
}

scan_key_pair () {
    echo
    echo "Scanning key pairs..."
    for kp in $(aws --region $region ec2 describe-key-pairs --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"KeyPairId":/{print$NF}' | tr -d '",'); do
        echo "KeyPair: $kp"
        (set -x; aws ec2 --region ${region} delete-key-pair --key-pair-id $kp)
    done
}
  
scan_tag () {
    echo
    echo "Scanning tags..."
    for tag in $(aws --region $region ec2 describe-tags --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"ResourceId":/{print$NF}' | tr -d '",'); do
        echo "Tag: $tag"
        (set -x; aws ec2 --region ${region} delete-tags --resources $tag)
    done
}
  
scan_images () {
    echo
    echo "Scan images..."
    for im in $(aws --region $region ec2 describe-images --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"ImageId":/{print$NF}' | tr -d '",'); do
        echo "Image: $im"
        (set -x; aws ec2 --region $region deregister-image --image-id $im)
        for ss in $(aws ec2 describe-images --image-ids $im --region $region --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' --output text); do
            echo "Image snapshot: $ss"
            (set -x; aws ec2 --region $region delete-snapshot --snapshot-id $ss)
        done
    done
}

# This function will check if the return of a command was empty, case the return is empty meaning that the object already was deleted from amazon
checkResult () {
   result="$1"
   if [ "z$result" == "z" ]; then
        return 0
   else
        if [ "$result" == "$OWNER" ]; then
            sleep 5
            return 1
        fi
   fi
   return 0
}

scan_rds () {
    echo
    echo "checking RDS instance name:"
    for RDS_name in $(aws rds describe-db-instances --region $region --query 'DBInstances[*].DBInstanceIdentifier' --output text 2> /dev/null) ; do
        if [ "$RDS_name" == "$OWNER" ]; then
            echo "Deleting: $RDS_name" 
            (set -x; aws rds delete-db-instance --region $region --db-instance-identifier "$RDS_name" --skip-final-snapshot)
        fi
    done

    checkDone=1
    while [ $checkDone -eq 1 ]; do
        echo "Checking if the RDS instance still exist..."
        result=`aws rds describe-db-instances --region $region --query 'DBInstances[*].DBInstanceIdentifier' --output text`
        checkResult $result
        checkDone=$?
    done

    for RDS_db_param in $(aws rds describe-db-parameter-groups --region $region --output text | grep -v default | awk '{print $4}' 2> /dev/null) ; do 
        if [ "$RDS_db_param" == "$OWNER" ]; then
            echo "Deleting RDS db-parameter-group: $RDS_db_param"
            (set -x; aws rds delete-db-parameter-group --region $region --db-parameter-group-name $RDS_db_param)
        fi
    done

    for subnet in $(aws rds describe-db-subnet-groups --region $region --query "DBSubnetGroups[*].DBSubnetGroupName" --output text 2> /dev/null); do
        if [ "$subnet" == "$OWNER" ]; then
            echo "Deleting : $subnet"
            (set -x; aws rds delete-db-subnet-group --region $region --db-subnet-group-name $subnet)
        fi
    done
}

scan_k8s_clusters () {
    while true; do
        resources=()
        echo
        echo "Scaning eks..."
        for cluster in $(aws eks list-clusters --region $region --query 'clusters[*]' --output text); do
            if [ "$(aws eks describe-cluster --region $region --name $cluster --query 'cluster.tags.owner' --output text)" = "$OWNER" ]; then
                echo "cluster: $cluster"
                resources+=("$cluster")
                for ng in $(aws eks list-nodegroups --region $region --cluster-name $cluster --query 'nodegroups[*]' --output text); do
                    resources+=("$ng")
                    echo "nodegroup: $ng"
                    (set -x; aws eks delete-nodegroup --region $region --nodegroup-name $ng --cluster-name $cluster)
                done
                (set -x; aws eks delete-cluster --region $region --name $cluster)
            fi
        done
        [ ${#resources[@]} -eq 0 ] && break
    done
}

scan_repositories () {
    echo ""
    echo "scan repositories..."
    for repo in $(aws ecr describe-repositories --color off --region $region --query 'repositories[*].repositoryName' --output text); do
        if [[ "$repo" = "wsf-$OWNER-"* ]]; then
            echo "repository: $repo" 
            (set -x; aws ecr delete-repository --region $region --repository-name $repo --force)
            resources+=("$repo")
        fi
    done
}

export AWS_PAGER=
. cleanup-common.sh

read_regions aws
for regionres in "${REGIONS[@]}"; do
    region="${regionres/,*/}"
    [[ "$region" =~ "[0-9]$" ]] || region="${region%?}"
    echo "region: $region"

    scan_k8s_clusters
    scan_rds

    vpcs=($(aws --region $region ec2 describe-vpcs --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"VpcId":/{print$NF}' | tr -d '",'))
    while true; do
        resources=()

        echo
        echo "Scanning vpc..."
        for vpc in $(aws --region $region ec2 describe-vpcs --output=json --filters Name=tag:owner,Values="$OWNER" | awk '/"VpcId":/{print$NF}' | tr -d '",'); do
            echo "VPC: $vpc"
            resources+=($vpc)
            (set -x; aws ec2 --region=$region delete-vpc --vpc-id $vpc)
        done

        for vpc in ${vpcs[@]}; do
            scan_vpc_internet_gateway $vpc
            scan_vpc_subnet $vpc
            scan_vpc_route_table $vpc
            scan_vpc_network_acl $vpc
            scan_vpc_peering_connection $vpc
            scan_vpc_endpoint $vpc
            scan_vpc_nat_gateway $vpc
            scan_vpc_security_group $vpc
            scan_vpc_instance $vpc
            scan_vpc_vpn_connection $vpc
            scan_vpc_vpn_gateway $vpc
            scan_vpc_network_interface $vpc
            scan_vpc_dhcp_option $vpc
            scan_vpc_volume $vpc
        done
  
        scan_placement_group
        scan_internet_gateway
        scan_subnet
        scan_images
        scan_repositories

        [ "${#resources[@]}" -eq 0 ] && break
    done
  
    scan_key_pair
    scan_tag
  
    echo
done
delete_regions aws 
