
def AddProxy(vm, service):
  vm.RemoteCommand(f'sudo mkdir -p /etc/systemd/system/{service}.service.d')
  vm.RemoteCommand(f'printf "[Service]\\nEnvironment=\"HTTP_PROXY=$http_proxy\" \"HTTPS_PROXY=$https_proxy\" \"NO_PROXY=$no_proxy\"\\n" | sudo tee /etc/systemd/system/{service}.service.d/proxy.conf')

