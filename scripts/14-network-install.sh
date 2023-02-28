#!/bin/bash
. ./.version
. ./tmpdir/.env

echo ">>>>>>正在安装网络组件<<<<<<"

CALICO () {
sed \
    -e 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g' \
    -e 's@#   value: "192.168.0.0/16"@  value: '\"${KUBE_POD_CIDR}\"'@g' \
    ./network/calico/calico.yaml | tee ./tmpdir/calico.yaml
kubectl --kubeconfig=./tmpdir/pki/admin.conf apply -f ./tmpdir/calico.yaml
}

CANAL () {
sed \
    -e 's@canal_iface: ""@canal_iface: '\"${KUBE_NETWORK_IFACE}\"'@g' \
    -e 's@"Network": "10.244.0.0/16"@"Network": '\"${KUBE_POD_CIDR}\"'@g' \
    -e 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g' \
    -e 's@#   value: "192.168.0.0/16"@  value: '\"${KUBE_POD_CIDR}\"'@g' \
    ./network/canal/canal.yaml | tee ./tmpdir/canal.yaml
kubectl --kubeconfig=./tmpdir/pki/admin.conf apply -f ./tmpdir/canal.yaml
}

FLANNEL () {
sed \
    -e 's@"Network": "10.244.0.0/16"@"Network": '\"${KUBE_POD_CIDR}\"'@g' \
    ./network/flannel/kube-flannel.yaml | tee ./tmpdir/kube-flannel.yaml
kubectl --kubeconfig=./tmpdir/pki/admin.conf apply -f ./tmpdir/kube-flannel.yaml
}


if [ "${KUBE_NETWORK_PLUGIN}" = "calico" ]; then
CALICO
elif [ "${KUBE_NETWORK_PLUGIN}" = "canal" ]; then
CANAL
elif [ "${KUBE_NETWORK_PLUGIN}" = "flannel" ]; then
FLANNEL
fi

echo ">>>检查网络组件安装:"
while true
do
    kubectl --kubeconfig=./tmpdir/pki/admin.conf get node | grep 'NotReady' > /dev/null
    if [[ ! $? = 0 ]]; then
        sleep 10s;
        echo ">>>Pods启动状态:"
        kubectl --kubeconfig=./tmpdir/pki/admin.conf get pods -n kube-system -o wide
        echo ">>>Node就绪状态:"
        kubectl --kubeconfig=./tmpdir/pki/admin.conf get node -o wide
        break
    fi
done


