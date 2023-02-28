#!/bin/bash

do_install_repo() {
sed -e 's|^mirrorlist=|#mirrorlist=|g' \
         -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.tencent.com|g' \
         -i /etc/yum.repos.d/CentOS-*.repo
yum install epel-release -y
sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!//download\.fedoraproject\.org/pub!//mirrors.tencent.com!g' \
    -e 's!//download\.example/pub!//mirrors.tencent.com!g' \
    -e 's!http://mirrors!https://mirrors!g' \
    -i /etc/yum.repos.d/epel*.repo
curl -L https://mirrors.cloud.tencent.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
sed -i 's+download.docker.com+mirrors.tencent.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
}

do_download_rpm() {
for type in install reinstall;
do
    yum ${type} --downloadonly --downloaddir=./kube-rpm-all \
        sshpass openssl openssl-devel openssh chrony \
        telnet curl wget vim jq sysstat net-tools lsof nload iftop iotop htop socat \
        conntrack ipvsadm ipset iptables sysstat libseccomp nfs-utils cifs-utils \
        make gcc gcc-c++ pcre pcre-devel systemd systemd-devel zip unzip zlib-devel \
        yum-utils device-mapper-persistent-data lvm2 containerd.io
done
}

do_install_createrepo() {
yum install createrepo -y
cd ./kube-rpm-all
createrepo ./
cd ..
}

do_tar_rpm() {
tar -zcf kube-rpm-all.linux-amd64.tar.gz ./kube-rpm-all
}

do_sha256sum() {
sha256sum kube-rpm-all.linux-amd64.tar.gz > kube-rpm-all.linux-amd64.sha256
grep kube-rpm-all.linux-amd64.tar.gz kube-rpm-all.linux-amd64.sha256 | sha256sum -c
}

[ -d ./kube-rpm-all ] && rm -rf ./kube-rpm-all
[ -f ./kube-rpm-all.linux-amd64.tar.gz ] && rm -rf ./kube-rpm-all.linux-amd64.tar.gz
[ -f ./kube-rpm-all.linux-amd64.sha256 ] && rm -rf ./kube-rpm-all.linux-amd64.sha256
mkdir -p ./kube-rpm-all
do_install_repo
do_download_rpm
do_install_createrepo
do_tar_rpm
do_sha256sum



