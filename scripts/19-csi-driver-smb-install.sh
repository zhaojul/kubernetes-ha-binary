#!/bin/bash
. ./.version
. ./tmpdir/.env

# IMAGE_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
IMAGE_REGISTRY="docker.io"

if [ ${CSI_DRIVER_SMB} = true ]; then
helm upgrade csi-driver-smb \
    --kubeconfig ./tmpdir/pki/admin.conf \
    --namespace kube-system \
    --create-namespace \
    --debug \
    --wait \
    --install \
    --atomic \
    --set image.baseRepo="${IMAGE_REGISTRY}/kubelibrary" \
    --set image.smb.repository="${IMAGE_REGISTRY}/kubelibrary/smbplugin" \
    --set image.smb.tag="v1.9.0" \
    --set image.csiProvisioner.repository="${IMAGE_REGISTRY}/kubelibrary/csi-provisioner" \
    --set image.csiProvisioner.tag="v3.2.0" \
    --set image.livenessProbe.repository="${IMAGE_REGISTRY}/kubelibrary/livenessprobe" \
    --set image.livenessProbe.tag="v2.7.0" \
    --set image.nodeDriverRegistrar.repository="${IMAGE_REGISTRY}/kubelibrary/csi-node-driver-registrar" \
    --set image.nodeDriverRegistrar.tag="v2.5.1" \
    --set controller.replicas=2 \
    ./charts/csi-driver-smb/csi-driver-smb-v1.9.0.tgz
fi


