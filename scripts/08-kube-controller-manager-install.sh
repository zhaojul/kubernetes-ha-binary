#!/bin/bash
. ./.version
. ./tmpdir/.env
echo ">>>>>> 部署kube-controller-manager <<<<<<"
echo ">>> 推送kube-controller-manager到所有Master节点并启动服务"
for master_ip in ${MASTER_IPS[@]}
do
{
  echo ">>> ${master_ip}"
  scp -r ./kube-component/kubernetes/server/bin/kube-controller-manager root@${master_ip}:/usr/bin/kube-controller-manager
  scp -r ./systemd/kube-controller-manager.service root@${master_ip}:/etc/systemd/system/kube-controller-manager.service
  ssh root@${master_ip} "chmod +x /usr/bin/kube-controller-manager;"
  ssh root@${master_ip} "systemctl daemon-reload; systemctl enable kube-controller-manager.service --now; sleep 10s;"
  ssh root@${master_ip} "systemctl status kube-controller-manager.service | grep 'Active:';"
  ssh root@${master_ip} "kubectl get componentstatuses"
}&
done
wait

