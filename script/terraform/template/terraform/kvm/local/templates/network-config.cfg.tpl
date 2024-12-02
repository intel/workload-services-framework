
version: 2
ethernets:
%{for i,mac in macs ~}
  ens${i+3}:
    match:
      macaddress: ${mac}
    dhcp4: true
%{endfor~}
