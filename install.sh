#!/bin/bash
clear
[ $UID = 0 ] || { echo "Please use root run this scripts"; exit 1; }
echo `date +"%Y-%m-%d %H:%M:%S "`
echo "*******************************************************"
echo "             Kubernetes Setup Tools" 
echo "*******************************************************"

K8S_OS_INIT() {
    chmod 755 ./scripts/*.sh
    ./scripts/01-kube-system-config.sh
    sleep 3s
    ./scripts/02-kube-component-download.sh
    sleep 3s
    ./scripts/03-kube-system-init.sh
    sleep 10s
}

K8S_CORE_INSTALL() {
    ./scripts/04-kube-cert-install.sh
    sleep 10s
    ./scripts/05-kube-haproxy-install.sh
    sleep 10s
    ./scripts/06-kube-etcd-install.sh
    sleep 10s
    ./scripts/07-kube-apiserver-install.sh
    sleep 10s
    ./scripts/08-kube-controller-manager-install.sh
    sleep 10s
    ./scripts/09-kube-scheduler-install.sh
    sleep 10s
    ./scripts/10-kube-containerd-install.sh
    sleep 10s
    ./scripts/11-kubelet-install.sh
    sleep 10s
    ./scripts/12-kube-proxy-install.sh
    sleep 10s
    ./scripts/13-coredns-install.sh
    sleep 10s
}

K8S_NETWORK_INSTALL() {
    ./scripts/14-network-install.sh
    sleep 10s
}

K8S_APP_INSTALL() {
    ./scripts/15-ingress-nginx-install.sh
    sleep 10s
    ./scripts/16-kube-state-metrics-install.sh
    sleep 10s
    ./scripts/17-metrics-server-install.sh
}

K8S_CSI_DRIVER_INSTALL() {
    ./scripts/18-csi-driver-nfs-install.sh
    sleep 10s
    ./scripts/19-csi-driver-smb-install.sh
    sleep 10s
}

ARCHIVE() {
    ./scripts/20-archive-install.sh
}


INSTALL() {
echo "This will install k8s on your target hosts."
while true
do
   read -r -p "Do you accept it? [Y/N]" ACCEPT
   case ${ACCEPT} in
       [yY][eE][sS]|[yY])
       echo "You chose to continue";
       K8S_OS_INIT
       K8S_CORE_INSTALL
       K8S_NETWORK_INSTALL
       K8S_APP_INSTALL
       K8S_CSI_DRIVER_INSTALL
       ARCHIVE
       break;
       ;;
       [nN][oO]|[nN])
       echo -e "\033[31mCancel\033[0m";
       exit 1;
       ;;
       *)
       echo -e "\033[31mInvalid Input\033[0m";
       ;;
  esac
done
}

INSTALL


