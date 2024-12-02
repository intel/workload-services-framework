all:
  children:
    worker:
      hosts:
%{ for i in range(length(hosts)) ~}
        worker-${i}:
          ansible_host: "${hosts[i]}"
          ansible_port: "${ports[i]}"
          ansible_user: "${users[i]}"
          ansible_connection: "${connections[i]}"
          private_ip: "${private_ips[i]}"
%{ endfor ~}
