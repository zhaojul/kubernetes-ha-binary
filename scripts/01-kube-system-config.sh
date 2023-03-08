#!/bin/bash
clear
echo "------------------------------------------------------------------------------------------------------------------"
echo " * 你需要配置以下内容:"
echo " * Kubernetes集群Master节点IP, Kubernetes集群Node节点IP, 请注意: Master节点数量必须且只能是3个!"
echo " * Kubernetes Apiserver VIP地址, 可以为云上LB地址,也可以是VM地址, 但需要根据环境实际情况进行选择."
echo " * Kubernetes集群网路类型,默认calico,可选canal或flannel;"
echo " * 所有节点的root密码, 请确保VIP节点,master节点,node节点的root密码相同."
echo "------------------------------------------------------------------------------------------------------------------"
echo ""
while true
do
   read -r -p "是否继续? [Y/N] " ACCEPT
   case ${ACCEPT} in
       [yY][eE][sS]|[yY])
       echo "You chose to continue";
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

NODEPOOLID=`cat /dev/urandom | head -n 20 | cksum | head -c 8`

READPAR1 () {
read -p "请输入集群名称(默认kubernetes), 仅支持小写英文输入: " CLUSTERNAME
CLUSTERNAME=${CLUSTERNAME}
[ ! "${CLUSTERNAME}x" == "x" ] || CLUSTERNAME="kubernetes"
read -p "请输入节点池名称(默认default), 仅支持小写英文输入: " NODEPOOLNAME
NODEPOOLNAME=${NODEPOOLNAME}
[ ! "${NODEPOOLNAME}x" == "x" ] || NODEPOOLNAME="default"
}

READPAR2 () {
read -p "请输入Kubernetes Apiserver VIP地址,该地址会被作为Control Plane Endpoint: " vip
HAPROXY_IP="${vip}"
HAPROXY_NAME="k8s-${NODEPOOLNAME}-masterpool-${NODEPOOLID}-slb"

read -p "请输入MASTER节点地址,三个IP之间以空格隔开: " masterip
K8S_M1=`echo ${masterip} |cut -d " " -f 1`
K8S_M2=`echo ${masterip} |cut -d " " -f 2`
K8S_M3=`echo ${masterip} |cut -d " " -f 3`
MASTER_IPS=( ${masterip} )
if [ "${K8S_M1}x" == "x" ] || [ "${K8S_M2}x" == "x" ] || [ "${K8S_M3}x" == "x" ] || [ "${HAPROXY_IP}x" == "x" ]; then
   echo "您输入了空值,请重新输入"
   READPAR2
fi

while true
do
   read -r -p "是否将Master加入到Worker节点中? [Y/N] " ACCEPT
   case ${ACCEPT} in
       [yY][eE][sS]|[yY])
       MASTER_IS_WORKER="true";
       break;
       ;;
       [nN][oO]|[nN])
       MASTER_IS_WORKER="false";
       break;
       ;;
       *)
       echo -e "\033[31mInvalid Input\033[0m";
       ;;
  esac
done

}

READPAR3 () {
read -p "请输入NODE节点地址,多个IP中间以空格隔开: " nodeip
NODE_IPS=( ${nodeip} )
if [ "${nodeip}x" == "x" ]; then
    echo "您输入了空值,请重新输入"
    READPAR3
fi
}

READPAR4 () {
read -p "请输入节点的root密码(请确保master节点和node节点的root密码相同): " rootpwd
ROOT_PWD=${rootpwd}
if [ "${rootpwd}x" == "x" ]; then
    echo "您输入了空值,请重新输入"
    READPAR4
else
echo "你输入的密码为 ${rootpwd}"
fi
}

READPAR5 () {
echo "
网段选择: pod 和 service 的网段不能与服务器网段重叠，
示例参考：
    * 如果服务器网段为: 10.0.0.0/8
        pod 网段可设置为: 172.20.0.0/16
        service 网段可设置为 172.21.0.0/16
    * 如果服务器网段为: 172.16.0.0/12
        pod 网段可设置为: 10.244.0.0/16
        service 网段可设置为 10.96.0.0/16
    * 如果服务器网段为: 192.168.0.0/16
        pod 网段可设置为: 10.244.0.0/16
        service 网段可设置为 10.96.0.0/16
"
read -p "请输入Pod网络CIDR(默认10.244.0.0/16): " podcidr
KUBE_POD_CIDR=${podcidr}
[ ! "${podcidr}x" == "x" ] || KUBE_POD_CIDR="10.244.0.0/16";
read -p "请输入Service网络CIDR(默认10.96.0.0/16): " servicecidr
KUBE_SERVICE_CIDR=${servicecidr}
[ ! "${servicecidr}x" == "x" ] || KUBE_SERVICE_CIDR="10.96.0.0/16";
KUBE_SERVICE_IP="`echo ${KUBE_SERVICE_CIDR} | awk -F. '{print $1 "." $2 "." $3}'`.1"
KUBE_DNS_SVC_IP="`echo ${KUBE_SERVICE_CIDR} | awk -F. '{print $1 "." $2 "." $3}'`.10"
}

READPAR6 () {
while true
do
echo "
选择Kubernetes集群网络组件类型, 默认安装Calico网络组件.
Calico (default)     [1], 
Canal                [2],
Flannel              [3],
";
read -r TYPE
if [ "x${TYPE}" = "x" ] || [ "x${TYPE}" = "x1" ]; then
    echo "你选择了安装Calico,安装工具会自动安装该网络组件";
    KUBE_NETWORK_PLUGIN="calico"
    break;
elif [ "x${TYPE}" = "x2" ]; then
    echo "你选择了安装Canal,安装工具会自动安装该网络组件";
    KUBE_NETWORK_PLUGIN="canal"
    break;
elif [ "x${TYPE}" = "x3" ]; then
    echo "你选择了安装Flannel,安装工具会自动安装该网络组件";
    KUBE_NETWORK_PLUGIN="flannel"
    break;
else
   echo -e "\033[31mInvalid Input\033[0m";
fi
done
}

READPAR7 () {
while true
do
   read -r -p "是否安装csi-driver-nfs组件? [Y/N] " ACCEPT
   case ${ACCEPT} in
       [yY][eE][sS]|[yY])
       CSI_DRIVER_NFS="true";
       break;
       ;;
       [nN][oO]|[nN])
       CSI_DRIVER_NFS="false";
       break;
       ;;
       *)
       echo -e "\033[31mInvalid Input\033[0m";
       ;;
  esac
done

while true
do
   read -r -p "是否安装csi-driver-smb组件? [Y/N] " ACCEPT
   case ${ACCEPT} in
       [yY][eE][sS]|[yY])
       CSI_DRIVER_SMB="true";
       break;
       ;;
       [nN][oO]|[nN])
       CSI_DRIVER_SMB="false";
       break;
       ;;
       *)
       echo -e "\033[31mInvalid Input\033[0m";
       ;;
  esac
done
}


MASTERHOSTNAME () {
i=0
for ip in ${MASTER_IPS[@]}
do
let i++
  echo "k8s-${NODEPOOLNAME}-masterpool-${NODEPOOLID}-${i}"
  echo 
done
}

CHECKHAPROXY () {
echo "HAproxy节点IP:                        ${HAPROXY_IP}"
echo "HAproxy节点Hostname:                  ${HAPROXY_NAME}"
echo "Kubernetes Control Plane Endpoint:    https://${HAPROXY_IP}:6443"
}

CHECKMASTER () {
c=0
for line in `MASTERHOSTNAME`
do
    mastername[${c}]=$line
    let c=${c}+1
done

MASTER_NAMES=`echo ${mastername[@]}`
echo "MASTER节点IP:                         ${MASTER_IPS[@]}"
echo "MASTER节点Hostname:                   ${MASTER_NAMES}"
}

NODEHOSTNAME () {
i=0
for ip in ${NODE_IPS[@]}
do
let i++
  echo "k8s-${NODEPOOLNAME}-nodepool-${NODEPOOLID}-${i}"
done
}

CHECKNODE () {
c=0
for line in `NODEHOSTNAME`
do
    nodename[${c}]=${line}
    let c=${c}+1
done

NODE_NAMES=`echo ${nodename[@]}`
echo "NODE节点IP:                           ${NODE_IPS[@]}"
echo "NODE节点Hostname:                     ${NODE_NAMES}"
}


CONFIG () {
READPAR1
READPAR2
READPAR3
READPAR4
READPAR5
READPAR6
READPAR7
}

CONFIG

while true
do
    echo ""
    echo "---------------------------------------------------------------------------"
    echo "* Below is all the information you entered:"
    echo "* Kubernetes Name:                        ${CLUSTERNAME}"
    echo "* Kubernetes Control Plane Endpoint:      https://${HAPROXY_IP}:6443"
    echo "* kubernetes Master IPs:                  ${masterip}"
    echo "* Kubernetes Node IPs:                    ${nodeip}"
    echo "* Kubernetes Nodes root password:         ${ROOT_PWD}"
    echo "* Kubernetes Nodepool Name:               ${NODEPOOLNAME}"
    echo "* Kubernetes podCIDR:                     ${KUBE_POD_CIDR}"
    echo "* Kubernetes serviceCIDR:                 ${KUBE_SERVICE_CIDR}"
    echo "* Kubernetes Network Plugin:              ${KUBE_NETWORK_PLUGIN}"
    echo "---------------------------------------------------------------------------"
    read -r -p "确定请输入[Y], 重新输入[N]: " ACCEPT
    case ${ACCEPT} in
        [yY][eE][sS]|[yY])
        echo "You chose to continue";
        break;
        ;;
        [nN][oO]|[nN])
        CONFIG
        ;;
        *)
        echo -e "\033[31mInvalid Input\033[0m";
        ;;
    esac
done

CHECKHAPROXY
CHECKMASTER
CHECKNODE

mkdir ./tmpdir
cat > ./tmpdir/.env <<EOF
CLUSTERNAME="${CLUSTERNAME}"
NODEPOOLNAME="${NODEPOOLNAME}"
NODEPOOLID="${NODEPOOLID}"
HAPROXY_NAME="${HAPROXY_NAME}"
HAPROXY_IP="${HAPROXY_IP}"
MASTER_NAMES=( ${MASTER_NAMES} )
MASTER_IPS=( ${masterip} )
NODE_NAMES=( ${NODE_NAMES} )
NODE_IPS=( ${nodeip} )
ROOT_PWD="$ROOT_PWD"
MASTER_IS_WORKER=${MASTER_IS_WORKER}

KUBE_NETWORK_IFACE="eth0"
KUBE_NETWORK_PLUGIN="${KUBE_NETWORK_PLUGIN}"
KUBE_SERVICE_IP="${KUBE_SERVICE_IP}"
KUBE_SERVICE_CIDR="${KUBE_SERVICE_CIDR}"
KUBE_POD_CIDR="${KUBE_POD_CIDR}"
KUBE_DNS_SVC_IP="${KUBE_DNS_SVC_IP}"
KUBE_DNS_DOMAIN="cluster.local"

CSI_DRIVER_NFS="${CSI_DRIVER_NFS}"
CSI_DRIVER_SMB="${CSI_DRIVER_SMB}"

EOF

