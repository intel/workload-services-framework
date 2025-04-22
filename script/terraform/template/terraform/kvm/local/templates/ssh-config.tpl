
Host ${hosts}
  ProxyCommand ssh -p ${remote_port} ${remote_user}@${remote_host} -W %h:%p

