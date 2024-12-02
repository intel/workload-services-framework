
Host ${hosts}
  ProxyCommand ssh -p ${remote_port} -i ${identity_file} ${remote_user}@${remote_host} -W %h:%p

