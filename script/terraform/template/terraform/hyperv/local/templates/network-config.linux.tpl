
version: 2
renderer: networkd
ethernets:
#  zz-all-en:
#    match:
#      name: "en*"
#    dhcp4: true
#    dhcp6: false
#    optional: true
  zz-all-eth:
    match:
      name: "eth*"
    dhcp4: true
    dhcp6: false
    optional: true
