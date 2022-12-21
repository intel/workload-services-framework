
# HTTPS configuration

**Machine prerequisites**

```bash
Istio service-mesh installed
Istio-Ingress-Gateway service configured as NodePort
Namespace 'default' labeled with istio-injection=enabled: 
$ kubectl label namespace default istio-injection=enabled
```

**Create certificates for your service**


Create a root certificate and private key to sign the certificates for your services:
```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:3072 -subj '/O=nighthawk Inc./CN=night.com' -keyout night.com.key -out night.com.crt
```

Create a certificate and a private key for sm-nighthawk-server.night.com:
```
openssl req -out sm-nighthawk-server.night.com.csr -newkey rsa:3072 -nodes -keyout sm-nighthawk-server.night.com.key -subj "/CN=sm-nighthawk-server.night.com/O=nighthawk organization"

openssl x509 -req -sha256 -days 365 -CA night.com.crt -CAkey night.com.key -set_serial 1 -in sm-nighthawk-server.night.com.csr -out sm-nighthawk-server.night.com.crt
```

Create a secret for the ingress gateway:
```
$ kubectl create -n istio-system secret tls nighthawk-credential --key=sm-nighthawk-server.night.com.key --cert=sm-nighthawk-server.night.com.crt
```




**Cluster configuration**

The [config](https://github.com/intel-sandbox/benchmark_release/tree/main/config/HTTPS) contains nighthawk configmap, deployment, service, virtual service and gateway. For scaling istio-ingressgateway (2vCPU, 4vCPU, 8vCPU,16vCPU) use: [istio-ingressgateway](https://github.com/intel-sandbox/benchmark_release/tree/main/config/BASELINE)

Nighthawk server configmap:
```
$ kubectl create configmap nighthawk --from-file nighthawk-server-cm.yaml
```

Nighthawk server deployment and service:
```
$ kubectl apply -f nighthawk-server-deploy.yaml
```

Istio gateway and virtual service:
```
$ kubectl apply -f istio-gateway_https.yaml
```

**Prepare variables**

```
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')

export TCP_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].nodePort}')

export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
```

Unset proxy:
```
unset no_proxy NO_PROXY http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
```

Navigate to directory with generated keys/certs and run curl to get response from nighthawk server:
```
curl -v -HHost:sm-nighthawk-server.night.com --resolve "sm-nighthawk-server.night.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" \
--cacert night.com.crt "https://sm-nighthawk-server.night.com:$SECURE_INGRESS_PORT/"
```