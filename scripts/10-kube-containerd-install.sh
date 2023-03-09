#!/bin/bash
. ./.version
. ./tmpdir/.env
echo ">>>>>> 安装 containerd <<<<<<"

if [ ${MASTER_IS_WORKER} = true ]; then
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${NODE_IPS[@]}"
fi

for node in ${NODE};
do
{
    while true
    do
      RETURN_NUM=`ssh root@${node} 'systemctl status containerd.service > /dev/null; echo "$?"'`
        if [[ ${RETURN_NUM} = 0 ]]; then
          echo ">>> change: ${node} install containerd done"
          break
        else
          echo ">>> change: ${node} start install containerd"
          scp -r ./kube-component/crictl/crictl root@${node}:/usr/bin/crictl
          scp -r ./config/containerd/crictl.yaml root@${node}:/etc/crictl.yaml
          ssh root@${node} "if [ ! -f /etc/yum.repos.d/kube-rpm.repo ]; then yum-config-manager --add-repo https://mirrors.cloud.tencent.com/docker-ce/linux/centos/docker-ce.repo; sed -i 's+download.docker.com+mirrors.cloud.tencent.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo; fi;"
          ssh root@${node} "systemctl disable --now docker.service; systemctl stop containerd.service; rm -rf /var/lib/docker; rm -rf /var/lib/containerd; rm -rf /etc/containerd"
          ssh root@${node} "yum install -y yum-utils device-mapper-persistent-data lvm2 containerd.io; chmod 755 /usr/bin/crictl"
          ssh root@${node} "mkdir -p /etc/containerd; containerd config default > /etc/containerd/config.toml;"
          ssh root@${node} 'sed -i -e "s#SystemdCgroup = false#SystemdCgroup = true#" -e "s#k8s.gcr.io#docker.io/kubelibrary#" -e "s#registry.k8s.io#docker.io/kubelibrary#" /etc/containerd/config.toml;'
          ssh root@${node} "systemctl daemon-reload; systemctl enable containerd.service --now;"
          sleep 5s
        fi
   done
}&
done
wait

echo ">>> containerd 安装完成 <<<"

if [ -f ./kube-images-all.linux-amd64.tar.gz ]; then
 for node in ${NODE};
  do
   {
    scp -r ./kube-images-all.linux-amd64.tar.gz root@${node}:/tmp/kube-images-all.linux-amd64.tar.gz
    ssh root@${node} "cd /tmp; gzip -d kube-images-all.linux-amd64.tar.gz; ctr -n k8s.io image import kube-images-all.linux-amd64.tar; rm -rf kube-images-all.linux-amd64.tar;"
   }&
  done
  wait
fi


