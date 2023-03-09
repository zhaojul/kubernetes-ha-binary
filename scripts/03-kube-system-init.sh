#!/bin/bash
. ./.version
. ./tmpdir/.env

do_config_hostname() {
echo ">>>>>> 配置主机名 <<<<<<"
rm -rf ./tmpdir/hosts
touch ./tmpdir/hosts
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > ./tmpdir/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> ./tmpdir/hosts
echo "${KUBE_APISERVER_VIP}  ${KUBE_APISERVER_NAME}" >> ./tmpdir/hosts

i=0
for ip in ${MASTER_IPS[@]}
do
let i++
  echo "${ip}  `echo ${MASTER_NAMES[@]} | cut -d " " -f $i`" >> ./tmpdir/hosts
done

i=0
for ip in ${NODE_IPS[@]}
do
let i++
  echo "${ip}  `echo ${NODE_NAMES[@]} | cut -d " " -f $i`" >> ./tmpdir/hosts
done

cp -r /etc/hosts /etc/hosts-default-backup 
cp -r ./tmpdir/hosts /etc/hosts
}

do_install_local_yum() {
cat > ./tmpdir/kube-rpm.repo <<EOF
[kube-rpm-stable]
name=kube-rpm-stable
baseurl=file:///var/cache/kube-rpm-all
gpgcheck=0
enabled=1
EOF

[ -d /var/cache/kube-rpm-all ] && rm -rf /var/cache/kube-rpm-all
[ -f /etc/yum.repos.d/kube-rpm.repo ] && rm -rf /etc/yum.repos.d/kube-rpm.repo
[ ! -d /etc/yum.repos.d/bak ] && mkdir -p /etc/yum.repos.d/bak
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
tar -zxf ./kube-rpm-all.linux-amd64.tar.gz -C /var/cache
cp -r ./tmpdir/kube-rpm.repo /etc/yum.repos.d/kube-rpm.repo
yum clean all
yum makecache
}

do_config_ssh_authoriz() {
echo ">>>>>> 设置ssh免密登陆 <<<<<<"
yum -y install sshpass jq openssl openssh telnet
if [ ! -f ~/.ssh/id_rsa ]; then
ssh-keygen -t rsa -P "" -C "Kubernetes-Setup-Tools" -f ~/.ssh/id_rsa
fi

if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

for node in ${NODE};
do
  echo ">>>${node}";
  sshpass -p ${ROOT_PWD} ssh-copy-id -o stricthostkeychecking=no root@${node}
done

}

do_k8s_install_local_yum() {
echo ">>>>>> 配置K8S所有节点使用本地YUM源 <<<<<<"
if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

for node in ${NODE};
do
  echo ">>>>>>>> ${node} <<<<<<";
  scp -r ./kube-rpm-all.linux-amd64.tar.gz root@${node}:/tmp/kube-rpm-all.linux-amd64.tar.gz
  ssh -o stricthostkeychecking=no root@${node} "rm -rf /etc/yum.repos.d/kube-rpm.repo; rm -rf /var/cache/kube-rpm-all; mkdir -p /etc/yum.repos.d/bak; mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/; tar -zxf /tmp/kube-rpm-all.linux-amd64.tar.gz -C /var/cache; rm -rf /tmp/kube-rpm-all.linux-amd64.tar.gz;"
  scp -r ./tmpdir/kube-rpm.repo root@${node}:/etc/yum.repos.d/kube-rpm.repo
done
}

do_k8s_install_cn_yum() {
echo ">>>>>> 配置K8S所有节点使用Tencent Mirror,加速安装 <<<<<<"
if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

for node in ${NODE};
do
  echo ">>>>>>>> ${node} <<<<<<";
  ssh root@${node} "sed -e 's|^mirrorlist=|#mirrorlist=|g' \
         -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.cloud.tencent.com|g' \
         -i.bak \
         /etc/yum.repos.d/CentOS-*.repo"
  ssh root@${node} "yum -y install epel-release"
  ssh root@${node} "sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!//download\.fedoraproject\.org/pub!//mirrors.cloud.tencent.com!g' \
    -e 's!//download\.example/pub!//mirrors.cloud.tencent.com!g' \
    -e 's!http://mirrors!https://mirrors!g' \
    -i /etc/yum.repos.d/epel*.repo"
done
}

cp -r ./kube-component/cfssl* /usr/bin/
cp -r ./kube-component/kubernetes/server/bin/kubeadm /usr/bin/kubeadm
cp -r ./kube-component/kubernetes/server/bin/kubectl /usr/bin/kubectl
cp -r ./kube-component/helm/linux-amd64/helm /usr/bin/helm
chmod +x /usr/bin/cfssl* /usr/bin/{kubeadm,kubectl,helm}

do_config_hostname

if [ -f ./kube-rpm-all.linux-amd64.tar.gz ]; then
do_install_local_yum
do_config_ssh_authoriz
do_k8s_install_local_yum
else
do_config_ssh_authoriz
do_k8s_install_cn_yum
fi

cat > ./tmpdir/limits.conf  <<EOF
*          hard    core      0
*          soft    nproc     65535
*          hard    nproc     65535
*          soft    nofile    65535
*          hard    nofile    65535
root       soft    nproc     unlimited
EOF


echo ">>>>>> 正在为所有节点安装基础的依赖包并修改配置,这需要较长的一段时间 <<<<<<"
if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

i=0
for node in ${NODE};
do
  let i++
  echo ">>>>>>>> ${node} 节点环境准备中 <<<<<<";
  ssh -o stricthostkeychecking=no root@${node} "cp -r /etc/hosts /etc/hosts.back"
  scp -r ./tmpdir/hosts root@${node}:/etc/hosts
  ssh root@${node} "hostnamectl set-hostname `echo ${KUBE_APISERVER_NAME} ${MASTER_NAMES[@]} ${NODE_NAMES[@]} | cut -d " " -f $i`"
done

if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

for node in ${NODE};
do
{
  ssh root@${node} "systemctl stop firewalld; systemctl disable firewalld; systemctl stop dnsmasq; systemctl disable dnsmasq; systemctl stop ntpd; systemctl disable ntpd; systemctl stop postfix; systemctl disable postfix;"
  ssh root@${node} "iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat && iptables -P FORWARD ACCEPT"
  ssh root@${node} "swapoff -a; sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab; setenforce 0"
  ssh root@${node} "sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config"
  ssh root@${node} "yum -y install yum-utils chrony curl wget vim sysstat net-tools openssl openssh lsof socat nfs-utils cifs-utils conntrack ipvsadm ipset iptables sysstat libseccomp; systemctl disable rpcbind;"
  ssh root@${node} "timedatectl set-timezone Asia/Shanghai; timedatectl set-local-rtc 0; systemctl restart chronyd; systemctl enable chronyd; systemctl restart rsyslog; systemctl restart crond"
  ssh root@${node} "cp /etc/sysctl.conf /etc/sysctl.conf.back; echo > /etc/sysctl.conf; sysctl -p"
  scp -r ./config/kernel/kubernetes.conf root@${node}:/etc/sysctl.d/kubernetes.conf
  ssh root@${node} "rm -rf /etc/security/limits.d/*"
  scp -r ./tmpdir/limits.conf root@${node}:/etc/security/limits.d/kubernetes.conf
  scp -r ./config/modules-load/ipvs.conf root@${node}:/tmp/ipvs.conf
  scp -r ./config/modules-load/containerd.conf root@${node}:/tmp/containerd.conf
  ssh root@${node} "cat /tmp/ipvs.conf > /etc/modules-load.d/ipvs.conf; rm -rf /tmp/ipvs.conf; cat /tmp/containerd.conf > /etc/modules-load.d/containerd.conf; rm -rf /tmp/containerd.conf; systemctl enable systemd-modules-load.service;"
}&
done
wait

echo ">>>>>> 配置rsyslog与logrotate服务 <<<<<<"
for node in ${MASTER_IPS[@]};
do
{
  scp -r ./config/logrotate/etcd root@${node}:/etc/logrotate.d/etcd
  scp -r ./config/logrotate/kubernetes root@${node}:/etc/logrotate.d/kubernetes
  scp -r ./config/rsyslog/etcd.conf root@${node}:/etc/rsyslog.d/etcd.conf
  scp -r ./config/rsyslog/kubernetes.conf root@${node}:/etc/rsyslog.d/kubernetes.conf
  scp -r ./config/crontab/etcd root@${node}:/etc/cron.hourly/etcd
  scp -r ./config/crontab/kubernetes root@${node}:/etc/cron.hourly/kubernetes
  ssh root@${node} "chmod 755 /etc/cron.hourly/etcd"
  ssh root@${node} "chmod 755 /etc/cron.hourly/kubernetes"
}&
done
wait

for node in ${NODE_IPS[@]};
do
{
  scp -r ./config/logrotate/kubernetes root@${node}:/etc/logrotate.d/kubernetes
  scp -r ./config/rsyslog/kubernetes.conf root@${node}:/etc/rsyslog.d/kubernetes.conf
  scp -r ./config/crontab/kubernetes root@${node}:/etc/cron.hourly/kubernetes
  ssh root@${node} "chmod 755 /etc/cron.hourly/kubernetes"
}&
done
wait


echo ">>>>>> 升级系统内核,内核版本为${Kernel_Version} <<<<<<"
if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

for node in ${NODE};
do
{
  echo ">>> ${node} 升级内核中"
  ssh root@${node} "mkdir /tmp/kernel-update/"
  scp -r ./kube-component/kernel-lt* root@${node}:/tmp/kernel-update/
  ssh root@${node} "cd /tmp/kernel-update/; yum install kernel-lt-*.rpm -y; sleep 3s; rm -rf /tmp/kernel-update;"
  ssh root@${node} "grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg; sleep 5s; grubby --default-kernel; sleep 5s; reboot;"
}&
done
wait

if [ ${KUBE_APISERVER_VIP_IS_EXTERNAL} = false ]; then
NODE="${KUBE_APISERVER_VIP} ${MASTER_IPS[@]} ${NODE_IPS[@]}"
else
NODE="${MASTER_IPS[@]} ${NODE_IPS[@]}"
fi

for node in ${NODE};
 do
    while true
    do
      ping -c 4 -w 100  ${node} > /dev/null
        if [[ $? = 0 ]];then
          echo " ${node} 节点 ping ok"
          break
        else
          echo " ${node} 节点还未reboot成功,请稍后... "
          sleep 5s
        fi
   done
done

echo ">>>>>> 导入kube-control-plane需要的环境变量 <<<<<<"
for node in ${MASTER_IPS[@]};
do
cat > ./tmpdir/kube-control-plane-${node} <<EOF
NODE_IP="${node}"
ETCD_ENDPOINTS="https://${MASTER_IPS[0]}:2379,https://${MASTER_IPS[1]}:2379,https://${MASTER_IPS[2]}:2379"
NODE_PORT_RANGE="3000-32767"
KUBE_SERVICE_CIDR="${KUBE_SERVICE_CIDR}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
EOF
scp -r ./tmpdir/kube-control-plane-${node} root@${node}:/etc/sysconfig/kube-control-plane
done


echo ">>>>>> 导入kube-node需要的环境变量 <<<<<<"

if [ ${MASTER_IS_WORKER} = true ]; then
i=o
for node in ${MASTER_IPS[@]};
do
cat > ./tmpdir/kube-node-${node} <<EOF
NODE_NAME="${MASTER_NAMES[i]}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
EOF
scp -r ./tmpdir/kube-node-${node} root@${node}:/etc/sysconfig/kube-node
let i++
done
fi

i=o
for node in ${NODE_IPS[@]};
do
cat > ./tmpdir/kube-node-${node} <<EOF
NODE_NAME="${NODE_NAMES[i]}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
EOF
scp -r ./tmpdir/kube-node-${node} root@${node}:/etc/sysconfig/kube-node
let i++
done


