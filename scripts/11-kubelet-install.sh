#!/bin/bash
. ./.version
. ./tmpdir/.env
echo ">>>>>> 部署kubelet <<<<<<"

if [ ${MASTER_IS_WORKER} = true ]; then
  i=0
  for node_ip in ${MASTER_IPS[@]};
  do
    echo ">>> ${node_ip}"
    BOOTSTRAP_TOKEN=`kubeadm token create --description kubelet-bootstrap-token --groups system:bootstrappers:${MASTER_NAMES[i]} --kubeconfig ./tmpdir/pki/admin.conf`
    sleep 5s
    kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt  --embed-certs=true --server=https://${KUBE_APISERVER_NAME}:6443 --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
    kubectl config set-credentials kubelet-bootstrap --token=${BOOTSTRAP_TOKEN} --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
    kubectl config set-context default --cluster=kubernetes --user=kubelet-bootstrap --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
    kubectl config use-context default --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
    let i++
  done
fi

i=0
for node_ip in ${NODE_IPS[@]};
do
  echo ">>> ${node_ip}"
  BOOTSTRAP_TOKEN=`kubeadm token create --description kubelet-bootstrap-token --groups system:bootstrappers:${NODE_NAMES[i]} --kubeconfig ./tmpdir/pki/admin.conf`
  sleep 5s
  kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt  --embed-certs=true --server=https://${KUBE_APISERVER_NAME}:6443 --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
  kubectl config set-credentials kubelet-bootstrap --token=${BOOTSTRAP_TOKEN} --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
  kubectl config set-context default --cluster=kubernetes --user=kubelet-bootstrap --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
  kubectl config use-context default --kubeconfig=./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig
  let i++
done


if [ ${MASTER_IS_WORKER} = true ]; then
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${NODE_IPS[@]}"
fi

echo ">>> 推送kubelet到所有节点"
for node_ip in ${NODE};
do
  echo ">>> ${node_ip}"
  scp -r ./kube-component/kubernetes/server/bin/kubelet root@${node_ip}:/usr/bin/kubelet
  ssh root@${node_ip} "chmod +x /usr/bin/kubelet; mkdir -p /var/lib/kubelet/pki /opt/cni/bin /var/log/kubernetes;"
  scp -r ./kube-component/cni/bin/* root@${node_ip}:/opt/cni/bin
  ssh root@${node_ip} "chmod +x /opt/cni/bin/*;"
  sed -e "s/{KUBE_DNS_SVC_IP}/${KUBE_DNS_SVC_IP}/g" -e "s/{KUBE_DNS_DOMAIN}/${KUBE_DNS_DOMAIN}/g" ./config/kubelet/config.yaml | tee ./tmpdir/kubelet-config-${node_ip}.yaml
  scp -r ./tmpdir/kubelet-config-${node_ip}.yaml root@${node_ip}:/var/lib/kubelet/config.yaml
  scp -r ./tmpdir/kubelet-bootstrap-${node_ip}.kubeconfig root@${node_ip}:/var/lib/kubelet/bootstrap-kubeconfig
  scp -r ./systemd/kubelet.service root@${node_ip}:/etc/systemd/system/kubelet.service
done

echo ">>> 启动kubelet服务"
for node_ip in ${NODE};
do
  ssh root@${node_ip} "systemctl daemon-reload; systemctl enable kubelet.service --now;"
  sleep 5s;
  ssh root@${node_ip} "systemctl status kubelet.service"
done

for node in ${NODE};
 do
  while true
  do
    echo "" | telnet ${node} 10250 | grep 'Escape'
    if [ $? -eq 0 ]; then
      echo " ${node} kubelet is running"
      sleep 5s
      break
    else
      echo " ${node} kubelet not running..."
      sleep 5s
    fi
  done
done

sleep 10s;
kubectl --kubeconfig=./tmpdir/pki/admin.conf get csr
echo ">>> Approve kubelet server cert csr"
kubectl --kubeconfig=./tmpdir/pki/admin.conf get csr | grep Pending | awk '{print $1}' | xargs kubectl --kubeconfig=./tmpdir/pki/admin.conf certificate approve
sleep 10s

if [ ${MASTER_IS_WORKER} = true ]; then
  for master in ${MASTER_NAMES[@]};
  do
    echo ">>> Add label kubernetes.io/role=agent for ${node}"
    kubectl --kubeconfig=./tmpdir/pki/admin.conf taint nodes ${master} node-role.kubernetes.io/control-plane=:NoSchedule
    kubectl --kubeconfig=./tmpdir/pki/admin.conf label nodes ${master} node-role.kubernetes.io/control-plane=""
  done
fi

for node in ${NODE_NAMES[@]};
do 
  echo ">>> Add label kubernetes.io/role=agent for ${node}"
  kubectl --kubeconfig=./tmpdir/pki/admin.conf label nodes ${node} node-role.kubernetes.io/agent=""
done

kubectl --kubeconfig=./tmpdir/pki/admin.conf get node -o wide


