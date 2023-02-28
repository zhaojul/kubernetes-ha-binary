#!/bin/bash
. ./.version
. ./tmpdir/.env

# IMAGE_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
IMAGE_REGISTRY="docker.io"

helm upgrade ingress-nginx \
   --kubeconfig ./tmpdir/pki/admin.conf \
   --namespace ingress-nginx \
   --create-namespace \
   --debug \
   --install \
   --wait \
   --atomic \
   --timeout 3m0s \
   --set controller.kind="Deployment" \
   --set controller.replicaCount="3" \
   --set controller.minAvailable="1" \
   --set controller.image.registry="${IMAGE_REGISTRY}" \
   --set controller.image.image="kubelibrary/ingress-nginx-controller" \
   --set controller.image.digest="" \
   --set controller.ingressClassResource.name="nginx" \
   --set controller.ingressClassResource.enable="true" \
   --set controller.ingressClassResource.default="false" \
   --set controller.service.enabled="true" \
   --set controller.service.type="NodePort" \
   --set controller.service.enableHttps="false" \
   --set controller.service.nodePorts.http="32080" \
   --set controller.service.nodePorts.https="32443" \
   --set controller.admissionWebhooks.enabled="false" \
   --set controller.admissionWebhooks.patch.image.registry="${IMAGE_REGISTRY}" \
   --set controller.admissionWebhooks.patch.image.image="kubelibrary/kube-webhook-certgen" \
   --set controller.admissionWebhooks.patch.image.digest="" \
   --set defaultBackend.enabled="true" \
   --set defaultBackend.name="defaultbackend" \
   --set defaultBackend.image.registry="${IMAGE_REGISTRY}" \
   --set defaultBackend.image.image="kubelibrary/defaultbackend-amd64" \
   --set defaultBackend.replicaCount="1" \
   --set defaultBackend.minAvailable="1" \
   --set rbac.create="true" \
   --set serviceAccount.create="true" \
   --set podSecurityPolicy.enabled="true" \
   ./charts/ingress-nginx/ingress-nginx-4.4.2.tgz

