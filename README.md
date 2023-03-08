# 二进制安装高可用Kubernetes集群

工具全都是用shell显得比较笨重，仅能满足快速安装一套K8S集群，好处就是能快速修改配置或脚本实现自己想要的效果

## 整体结构

```
|                              Haproxy / SLB
|                                    |
|                                    |
|         |——————————————————————————|——————————————————————————|
|  Kube-ApiServer1(Master)    Kube-ApiServer2(Master)    Kube-ApiServer3(Master)
|         |——————————————————————————|——————————————————————————|
|      Kube-Node1                 Kube-Node2                 Kube-Node3 ...
```

## 组件版本

| 组件               | 版本                                                         |
| :----------------- | :----------------------------------------------------------- |
| Kubernetes         | v1.23.17                                                     |
| Haproxy            | 2.6.9                                                        |
| Etcd               | v3.5.6                                                       |
| CoreDNS            | 1.8.7                                                       |
| CNI                | v1.1.1                                                       |
| Calico             | v3.24.5                                                    |
| Flannel            | v0.21.2                                                      |
| Canal              | Flannel: v0.15.1;  Calico: v3.24.5                          |
| Ingress-nginx      | [4.4.2](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx/4.4.2) |
| kube-state-metrics | [4.16.0](https://artifacthub.io/packages/helm/prometheus-community/kube-state-metrics/4.16.0) |
| metrics-server     | [3.8.2](https://artifacthub.io/packages/helm/metrics-server/metrics-server/3.8.2) |
| csi-driver-nfs     | [v4.1.0](https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts/v4.1.0/csi-driver-nfs-v4.1.0.tgz) |
| csi-driver-smb     | [v1.9.0](https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts/v1.9.0/csi-driver-smb-v1.9.0.tgz) |



## 部署说明

默认只能支持三节点Master集群，不支持大于或者小于3节点Master

需要一台单独的机器作为部署机器,并拥有`root`权限

需要设置Haproxy节点和所有K8S节点的root密码为同一密码，脚本会使用该密码设置免密登录

操作系统仅支持CentOS7.9,并需要系统纯净无更改

### 在线部署

在部署机上执行

```
git clone https://github.com/kubespaces/kubernetes-ha-install.git
cd kubernetes-ha-install
git checkout v1.23.17.1
./install.sh
```

根据提示输入集群信息即可自动安装

### 离线部署

在[Release](https://github.com/kubespaces/kubernetes-ha-install/releases/tag/v1.23.17.1)下载[Source code(tar.gz)](https://github.com/kubespaces/kubernetes-ha-install/archive/refs/tags/v1.23.17.1.tar.gz)并拷贝到部署机解压，本地克隆代码也可以

下载下面的文件并拷贝到解压后的代码目录，脚本会检查本地是否有这三个文件，如果有会直接使用这三个文件，不再从网络上下载; 

[kube-component.linux-amd64.tar.gz](https://github.com/kubespaces/kubernetes-ha-install/releases/download/v1.23.17.1/kube-component.linux-amd64.tar.gz)

[kube-images-all.linux-amd64](https://github.com/kubespaces/kubernetes-ha-install/releases/download/v1.23.17.1/kube-images-all.linux-amd64.tar.gz)

[kube-rpm-all.linux-amd64](https://github.com/kubespaces/kubernetes-ha-install/releases/download/v1.23.17.1/kube-rpm-all.linux-amd64.tar.gz)

文件放置位置如下:

```
charts
config
docs
.git
install.sh
kube-component.linux-amd64.tar.gz
kube-images-all.linux-amd64.tar.gz
kube-rpm-all.linux-amd64.tar.gz
LICENSE
network
README.md
scripts
systemd
.version
```

然后执行`./install.sh`即可安装，相关提示和在线安装相同



## 需要改进的地方

工具还没有给集群添加节点的功能

Haproxy安装独立出来，方便在公有云环境部署



