BEGIN {
    cc=0
}
/SUT\/Info:/ && cc==0 {
    split(gensub(/.*INFO\s+SUT\/Info:/,"",1), fields)
    group=fields[1]
    if (group == "registry") {
        registry=fields[2]
    } else {
        ++n[group]
        ip_address[group][n[group]]=fields[2]
        internal_ip[group][n[group]]=fields[3]
    }
}
/docker_pt/ && /vm_util.py/ && /Running: ssh/ && /-p [0-9]+/ && /[a-zA-Z0-9_]+@[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ && cc==0 {
    match($0,/[a-zA-Z0-9_]+@[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)
    uip1=substr($0,RSTART,RLENGTH)
    ip1=gensub(/.*@/,"",1,uip1)
    username[ip1]=gensub(/@.*/,"",1,uip1)

    match($0,/ -p [0-9]+/)
    port[ip1]=gensub(/ -p /,"",1,substr($0,RSTART,RLENGTH))
}
/===cumulus-config.yaml===/ {
    cc=1
    next
}
/^\s*vm_groups:\s*$/ && cc==1 {
    vm_groups=1
}
/^\s*flags:\s*$/ && cc==1 {
    vm_groups=0
    flags=1
}
/^\s*[a-zA-Z_]+:\s*$/ && vm_groups==1 {
    group=gensub(/:/,"",1,$1)
}
/^\s*dpt_registry_map:/ && flags==1 && registry!="" {
    $0=gensub(/,.*/, "," registry "\"", 1)
}
#/^\s*cloud:\s*[A-Z]+\s*$/ && flags==1 {
#    next
#}
/^\s*append_kernel_command_line:/ && flags==1 {
    next
}
cc==1 {
    print $0
}
/^\s*vm_spec:/ && vm_groups==1 {
    ns=substr($0,1,index($0,$1)-1)
    print ns "static_vms:"
    for (i=1;i<=n[group];i++) {
        print ns "- ip_address: " ip_address[group][i]
        print ns "  user_name: " username[ip_address[group][i]]
        print ns "  ssh_private_key: \"" keyfile "\""
        print ns "  internal_ip: " internal_ip[group][i]
        print ns "  ssh_port: " port[ip_address[group][i]]
    }
}
