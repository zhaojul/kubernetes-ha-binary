#!/bin/bash
. ./.version
. ./tmpdir/.env
echo ">>>>>> 部署kube-scheduler <<<<<<"
echo ">>> 推送kube-scheduler到所有Master节点并启动服务"
for master_ip in ${MASTER_IPS[@]}
do
  echo ">>> ${master_ip}"
  scp -r ./kube-component/kubernetes/server/bin/kube-scheduler root@${master_ip}:/usr/bin/kube-scheduler
  scp -r ./systemd/kube-scheduler.service root@${master_ip}:/etc/systemd/system/kube-scheduler.service
  ssh root@${master_ip} "chmod +x /usr/bin/kube-scheduler;"
  ssh root@${master_ip} "systemctl daemon-reload; systemctl enable kube-scheduler.service --now;"
  sleep 10s;
done

echo ">>> 检查kube-scheduler服务"
for master_ip in ${MASTER_IPS[@]}
do
{
  ssh root@${master_ip} "systemctl status kube-scheduler.service"
  ssh root@${master_ip} "kubectl get componentstatuses"
}&
done
wait

