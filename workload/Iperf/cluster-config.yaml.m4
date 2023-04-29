include(config.m4)

cluster:
- labels: {}
- labels: {}
ifelse(MODE,ingress,`dnl
  off_cluster: true
terraform:
  iperf_client_image: IMAGENAME(Dockerfile.1.iperf)
')dnl
