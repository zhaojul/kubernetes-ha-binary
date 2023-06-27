#!/bin/bash
. ./.version
. ./tmpdir/.env

# IMAGE_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
IMAGE_REGISTRY="docker.io"

if [ ${MASTER_IS_WORKER} = true ]; then
HOSTNETWORK="false"
else
HOSTNETWORK="true"
fi

helm upgrade kube-state-metrics \
    --kubeconfig ./tmpdir/pki/admin.conf \
    --namespace kube-system \
    --create-namespace \
    --debug \
    --wait \
    --install \
    --atomic \
    --set image.repository="${IMAGE_REGISTRY}/kubelibrary/kube-state-metrics" \
    --set podSecurityPolicy.enabled="true" \
    --set hostNetwork="${HOSTNETWORK}" \
    ./charts/kube-state-metrics/kube-state-metrics-4.22.3.tgz

