#!/bin/bash
. ./.version
. ./tmpdir/.env
echo ">>>>>> 部署kube-proxy <<<<<<"

if [ ${MASTER_IS_WORKER} = true ]; then
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${NODE_IPS[@]}"
fi

echo ">>> 推送kube-proxy到所有节点"
for node_ip in ${NODE};
do
  echo ">>> ${node_ip}"
  scp -r ./kube-component/kubernetes/server/bin/kube-proxy root@${node_ip}:/usr/bin/kube-proxy
  ssh root@${node_ip} "chmod +x /usr/bin/kube-proxy; mkdir -p /var/lib/kube-proxy /var/log/kubernetes"
  sed -e "s/{KUBE_DNS_SVC_IP}/${KUBE_DNS_SVC_IP}/g" -e "s/{KUBE_DNS_DOMAIN}/${KUBE_DNS_DOMAIN}/g" ./config/kube-proxy/config.yaml | tee ./tmpdir/kube-proxy-config-${node_ip}.yaml
  scp -r ./tmpdir/kube-proxy-config-${node_ip}.yaml root@${node_ip}:/var/lib/kube-proxy/config.yaml
  scp -r ./systemd/kube-proxy.service root@${node_ip}:/etc/systemd/system/kube-proxy.service
done

echo ">>> 启动kube-proxy服务"
for node_ip in ${NODE};
do
  ssh root@${node_ip} "systemctl daemon-reload; systemctl enable kube-proxy.service --now;"
  sleep 5s;
  ssh root@${node_ip} "systemctl status kube-proxy.service"
done




