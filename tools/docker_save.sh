#!/bin/bash

IMAGE_LIST=(
"docker.io/calico/cni:v3.24.5"
"docker.io/calico/kube-controllers:v3.24.5"
"docker.io/calico/node:v3.24.5"
"docker.io/flannel/flannel-cni-plugin:v1.1.2"
"docker.io/flannel/flannel:v0.21.5"
"docker.io/coredns/coredns:1.8.7"
"docker.io/kubelibrary/csi-node-driver-registrar:v2.5.1"
"docker.io/kubelibrary/csi-provisioner:v3.2.0"
"docker.io/kubelibrary/defaultbackend-amd64:1.5"
"docker.io/kubelibrary/flannel:v0.15.1"
"docker.io/kubelibrary/ingress-nginx-controller:v1.5.1"
"docker.io/kubelibrary/kube-state-metrics:v2.6.0"
"docker.io/kubelibrary/kube-webhook-certgen:v20220916-gd32f8c343"
"docker.io/kubelibrary/livenessprobe:v2.7.0"
"docker.io/kubelibrary/metrics-server:v0.6.2"
"docker.io/kubelibrary/nfsplugin:v4.1.0"
"docker.io/kubelibrary/pause:3.6"
"docker.io/kubelibrary/pause:3.7"
"docker.io/kubelibrary/smbplugin:v1.9.0"
)

for image in ${IMAGE_LIST[@]};
do
docker pull ${image}
done

docker save ${IMAGE_LIST[@]} | gzip > kube-images-all.linux-amd64.tar.gz
sha256sum kube-images-all.linux-amd64.tar.gz > kube-images-all.linux-amd64.sha256
grep kube-images-all.linux-amd64.tar.gz kube-images-all.linux-amd64.sha256 | sha256sum -c

