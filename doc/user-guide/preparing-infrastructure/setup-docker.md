# Docker Setup

The `docker` engine is a prerequisite to build the docker images. 

## Setup Docker

Follow the instructions to install the `docker` engine on your local system. The docker version `20.10.10` or later is required for full features.  

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

> It is recommended that you complete the [post-installation steps][post-installation steps] to manage `docker` as a non-root user.

## Setup Proxies

If you are behind a firewall, complete the following steps to setup the proxies:  

```shell
sudo mkdir -p /etc/systemd/system/docker.service.d
printf "[Service]\nEnvironment=\"HTTP_PROXY=$http_proxy\" \"HTTPS_PROXY=$https_proxy\" \"NO_PROXY=$no_proxy\"\n" | sudo tee /etc/systemd/system/docker.service.d/proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Docker Login

Optionally, login to your dockerhub account so that you can pull images from dockerhub.

## See Also

- [Docker Setup][Docker Setup]


[post-installation steps]: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
[Docker Setup]: https://docs.docker.com/engine/install/#server
