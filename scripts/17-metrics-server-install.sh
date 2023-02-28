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

helm upgrade metrics-server \
   --kubeconfig ./tmpdir/pki/admin.conf \
   --namespace kube-system \
   --create-namespace \
   --debug \
   --wait \
   --install \
   --atomic \
   --set image.repository="${IMAGE_REGISTRY}/kubelibrary/metrics-server" \
   --set image.tag="v0.6.1" \
   --set hostNetwork.enabled="${HOSTNETWORK}" \
   --set podDisruptionBudget.enabled="true" \
   --set podDisruptionBudget.minAvailable="1" \
   --set podDisruptionBudget.maxUnavailable="0" \
   ./charts/metrics-server/metrics-server-3.8.2.tgz

