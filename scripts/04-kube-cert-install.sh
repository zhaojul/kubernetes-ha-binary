#!/bin/bash
. ./.version
. ./tmpdir/.env
rm -rf ./tmpdir/pki
mkdir -p ./tmpdir/pki/etcd

echo ">>>>>> 生成CA根证书 <<<<<<"

cat > ./tmpdir/pki/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "876000h"
    },
    "profiles": {
      "etcd": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      },
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
EOF

cat > ./tmpdir/pki/etcd-ca-csr.json <<EOF
{
  "CN": "etcd-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cat > ./tmpdir/pki/kube-ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cfssl gencert -initca ./tmpdir/pki/etcd-ca-csr.json | cfssljson -bare ./tmpdir/pki/etcd/ca
openssl rsa  -in ./tmpdir/pki/etcd/ca-key.pem -out ./tmpdir/pki/etcd/ca.key
openssl x509 -in ./tmpdir/pki/etcd/ca.pem -out ./tmpdir/pki/etcd/ca.crt

cfssl gencert -initca ./tmpdir/pki/kube-ca-csr.json | cfssljson -bare ./tmpdir/pki/ca
openssl rsa  -in ./tmpdir/pki/ca-key.pem -out ./tmpdir/pki/ca.key
openssl x509 -in ./tmpdir/pki/ca.pem -out ./tmpdir/pki/ca.crt

for master in ${MASTER_IPS[@]};
do
  ssh root@${master} "mkdir -p /etc/kubernetes/pki/etcd";
  scp -r ./tmpdir/pki/etcd/ca.key root@${master}:/etc/kubernetes/pki/etcd/ca.key;
  scp -r ./tmpdir/pki/etcd/ca.crt root@${master}:/etc/kubernetes/pki/etcd/ca.crt;
  scp -r ./tmpdir/pki/ca.key root@${master}:/etc/kubernetes/pki/ca.key;
  scp -r ./tmpdir/pki/ca.crt root@${master}:/etc/kubernetes/pki/ca.crt;
done

for node in ${NODE_IPS[@]};
do
  ssh root@${node} "mkdir -p /etc/kubernetes/pki"
  scp -r ./tmpdir/pki/ca.crt root@${node}:/etc/kubernetes/pki/ca.crt;
done

echo ">>>>>> 生成etcd相关证书 <<<<<<"

i=0
for etcd_ip in ${MASTER_IPS[@]};
do
cat > ./tmpdir/pki/etcd/server-${etcd_ip}-csr.json <<EOF
{
  "CN": "${MASTER_NAMES[i]}",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "${MASTER_IPS[i]}",
    "127.0.0.1",
    "0000:0000:0000:0000:0000:0000:0000:0001"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cat > ./tmpdir/pki/etcd/peer-${etcd_ip}-csr.json <<EOF
{
  "CN": "${MASTER_NAMES[i]}",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "${MASTER_IPS[i]}",
    "127.0.0.1",
    "0000:0000:0000:0000:0000:0000:0000:0001"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert -ca=./tmpdir/pki/etcd/ca.crt -ca-key=./tmpdir/pki/etcd/ca.key -config=./tmpdir/pki/ca-config.json -profile=etcd ./tmpdir/pki/etcd/server-${etcd_ip}-csr.json | cfssljson -bare ./tmpdir/pki/etcd/server-${etcd_ip}
openssl rsa  -in ./tmpdir/pki/etcd/server-${etcd_ip}-key.pem -out ./tmpdir/pki/etcd/server-${etcd_ip}.key
openssl x509 -in ./tmpdir/pki/etcd/server-${etcd_ip}.pem -out ./tmpdir/pki/etcd/server-${etcd_ip}.crt
scp -r ./tmpdir/pki/etcd/server-${etcd_ip}.key root@${etcd_ip}:/etc/kubernetes/pki/etcd/server.key;
scp -r ./tmpdir/pki/etcd/server-${etcd_ip}.crt root@${etcd_ip}:/etc/kubernetes/pki/etcd/server.crt;

cfssl gencert -ca=./tmpdir/pki/etcd/ca.crt -ca-key=./tmpdir/pki/etcd/ca.key -config=./tmpdir/pki/ca-config.json -profile=etcd ./tmpdir/pki/etcd/peer-${etcd_ip}-csr.json | cfssljson -bare ./tmpdir/pki/etcd/peer-${etcd_ip}
openssl rsa  -in ./tmpdir/pki/etcd/peer-${etcd_ip}-key.pem -out ./tmpdir/pki/etcd/peer-${etcd_ip}.key
openssl x509 -in ./tmpdir/pki/etcd/peer-${etcd_ip}.pem -out ./tmpdir/pki/etcd/peer-${etcd_ip}.crt
scp -r ./tmpdir/pki/etcd/peer-${etcd_ip}.key root@${etcd_ip}:/etc/kubernetes/pki/etcd/peer.key;
scp -r ./tmpdir/pki/etcd/peer-${etcd_ip}.crt root@${etcd_ip}:/etc/kubernetes/pki/etcd/peer.crt;

let i++
done

cat > ./tmpdir/pki/etcd/healthcheck-client-csr.json <<EOF
{
  "CN": "kube-etcd-healthcheck-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./tmpdir/pki/etcd/ca.crt -ca-key=./tmpdir/pki/etcd/ca.key -config=./tmpdir/pki/ca-config.json -profile=etcd ./tmpdir/pki/etcd/healthcheck-client-csr.json | cfssljson -bare ./tmpdir/pki/etcd/healthcheck-client
openssl rsa  -in ./tmpdir/pki/etcd/healthcheck-client-key.pem -out ./tmpdir/pki/etcd/healthcheck-client.key
openssl x509 -in ./tmpdir/pki/etcd/healthcheck-client.pem -out ./tmpdir/pki/etcd/healthcheck-client.crt

for etcd_ip in ${MASTER_IPS[@]};
do
  scp -r ./tmpdir/pki/etcd/healthcheck-client.key root@${etcd_ip}:/etc/kubernetes/pki/etcd/healthcheck-client.key;
  scp -r ./tmpdir/pki/etcd/healthcheck-client.crt root@${etcd_ip}:/etc/kubernetes/pki/etcd/healthcheck-client.crt;
done


cat > ./tmpdir/pki/apiserver-etcd-client-csr.json <<EOF
{
  "CN": "kube-apiserver-etcd-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./tmpdir/pki/etcd/ca.crt -ca-key=./tmpdir/pki/etcd/ca.key -config=./tmpdir/pki/ca-config.json -profile=etcd ./tmpdir/pki/apiserver-etcd-client-csr.json | cfssljson -bare ./tmpdir/pki/apiserver-etcd-client
openssl rsa  -in ./tmpdir/pki/apiserver-etcd-client-key.pem -out ./tmpdir/pki/apiserver-etcd-client.key
openssl x509 -in ./tmpdir/pki/apiserver-etcd-client.pem -out ./tmpdir/pki/apiserver-etcd-client.crt

for etcd_ip in ${MASTER_IPS[@]};
do
  scp -r ./tmpdir/pki/apiserver-etcd-client.key root@${etcd_ip}:/etc/kubernetes/pki/apiserver-etcd-client.key;
  scp -r ./tmpdir/pki/apiserver-etcd-client.crt root@${etcd_ip}:/etc/kubernetes/pki/apiserver-etcd-client.crt;
done

echo ">>>>>> 生成kubernetes相关证书 <<<<<<"

i=0
for master_ip in ${MASTER_IPS[@]};
do
cat > ./tmpdir/pki/apiserver-${master_ip}-csr.json <<EOF
{
  "CN": "kube-apiserver",
  "hosts": [
    "localhost",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local",
    "${KUBE_APISERVER_NAME}",
    "${MASTER_NAMES[i]}",
    "127.0.0.1",
    "${KUBE_SERVICE_IP}",
    "${KUBE_APISERVER_VIP}",
    "${MASTER_IPS[i]}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cat > ./tmpdir/pki/kube-controller-manager-${master_ip}-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "127.0.0.1",
    "${MASTER_IPS[i]}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-controller-manager"
    }
  ] 
}
EOF

cat > ./tmpdir/pki/kube-scheduler-${master_ip}-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "hosts": [
    "${MASTER_NAMES[i]}",
    "localhost",
    "127.0.0.1",
    "${MASTER_IPS[i]}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-scheduler"
    }
  ] 
}
EOF

cfssl gencert -ca=./tmpdir/pki/ca.crt -ca-key=./tmpdir/pki/ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/apiserver-${master_ip}-csr.json | cfssljson -bare ./tmpdir/pki/apiserver-${master_ip}
openssl rsa  -in ./tmpdir/pki/apiserver-${master_ip}-key.pem -out ./tmpdir/pki/apiserver-${master_ip}.key
openssl x509 -in ./tmpdir/pki/apiserver-${master_ip}.pem -out ./tmpdir/pki/apiserver-${master_ip}.crt
scp -r ./tmpdir/pki/apiserver-${master_ip}.key root@${master_ip}:/etc/kubernetes/pki/apiserver.key;
scp -r ./tmpdir/pki/apiserver-${master_ip}.crt root@${master_ip}:/etc/kubernetes/pki/apiserver.crt;

cfssl gencert -ca=./tmpdir/pki/ca.crt -ca-key=./tmpdir/pki/ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/kube-controller-manager-${master_ip}-csr.json | cfssljson -bare ./tmpdir/pki/kube-controller-manager-${master_ip}
openssl rsa  -in ./tmpdir/pki/kube-controller-manager-${master_ip}-key.pem -out ./tmpdir/pki/kube-controller-manager-${master_ip}.key
openssl x509 -in ./tmpdir/pki/kube-controller-manager-${master_ip}.pem -out ./tmpdir/pki/kube-controller-manager-${master_ip}.crt
scp -r ./tmpdir/pki/kube-controller-manager-${master_ip}.key root@${master_ip}:/etc/kubernetes/pki/kube-controller-manager.key;
scp -r ./tmpdir/pki/kube-controller-manager-${master_ip}.crt root@${master_ip}:/etc/kubernetes/pki/kube-controller-manager.crt;

cfssl gencert -ca=./tmpdir/pki/ca.crt -ca-key=./tmpdir/pki/ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/kube-scheduler-${master_ip}-csr.json | cfssljson -bare ./tmpdir/pki/kube-scheduler-${master_ip}
openssl rsa  -in ./tmpdir/pki/kube-scheduler-${master_ip}-key.pem -out ./tmpdir/pki/kube-scheduler-${master_ip}.key
openssl x509 -in ./tmpdir/pki/kube-scheduler-${master_ip}.pem -out ./tmpdir/pki/kube-scheduler-${master_ip}.crt
scp -r ./tmpdir/pki/kube-scheduler-${master_ip}.key root@${master_ip}:/etc/kubernetes/pki/kube-scheduler.key;
scp -r ./tmpdir/pki/kube-scheduler-${master_ip}.crt root@${master_ip}:/etc/kubernetes/pki/kube-scheduler.crt;

kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt --embed-certs=true --server=https://${master_ip}:6443 --kubeconfig=./tmpdir/pki/controller-manager-${master_ip}.conf
kubectl config set-credentials system:kube-controller-manager --client-certificate=./tmpdir/pki/kube-controller-manager-${master_ip}.crt --client-key=./tmpdir/pki/kube-controller-manager-${master_ip}.key --embed-certs=true --kubeconfig=./tmpdir/pki/controller-manager-${master_ip}.conf
kubectl config set-context system:kube-controller-manager@kubernetes --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=./tmpdir/pki/controller-manager-${master_ip}.conf
kubectl config use-context system:kube-controller-manager@kubernetes --kubeconfig=./tmpdir/pki/controller-manager-${master_ip}.conf
scp -r ./tmpdir/pki/controller-manager-${master_ip}.conf root@${master_ip}:/etc/kubernetes/controller-manager.conf;

kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt --embed-certs=true --server=https://${master_ip}:6443 --kubeconfig=./tmpdir/pki/scheduler-${master_ip}.conf
kubectl config set-credentials system:kube-scheduler --client-certificate=./tmpdir/pki/kube-scheduler-${master_ip}.crt --client-key=./tmpdir/pki/kube-scheduler-${master_ip}.key --embed-certs=true --kubeconfig=./tmpdir/pki/scheduler-${master_ip}.conf
kubectl config set-context system:kube-scheduler@kubernetes --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=./tmpdir/pki/scheduler-${master_ip}.conf
kubectl config use-context system:kube-scheduler@kubernetes --kubeconfig=./tmpdir/pki/scheduler-${master_ip}.conf
scp -r ./tmpdir/pki/scheduler-${master_ip}.conf root@${master_ip}:/etc/kubernetes/scheduler.conf;

let i++
done

#apiserver-kubelet-client
cat > ./tmpdir/pki/apiserver-kubelet-client-csr.json <<EOF
{
  "CN": "kube-apiserver-kubelet-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./tmpdir/pki/ca.crt -ca-key=./tmpdir/pki/ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/apiserver-kubelet-client-csr.json | cfssljson -bare ./tmpdir/pki/apiserver-kubelet-client
openssl rsa  -in ./tmpdir/pki/apiserver-kubelet-client-key.pem -out ./tmpdir/pki/apiserver-kubelet-client.key
openssl x509 -in ./tmpdir/pki/apiserver-kubelet-client.pem -out ./tmpdir/pki/apiserver-kubelet-client.crt

for master_ip in ${MASTER_IPS[@]};
do
  scp -r ./tmpdir/pki/apiserver-kubelet-client.key root@${master_ip}:/etc/kubernetes/pki/apiserver-kubelet-client.key;
  scp -r ./tmpdir/pki/apiserver-kubelet-client.crt root@${master_ip}:/etc/kubernetes/pki/apiserver-kubelet-client.crt;
done

#kubeconfig for kubectl
cat > ./tmpdir/pki/kubernetes-admin-csr.json <<EOF
{
  "CN": "kubernetes-admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF

cfssl gencert -ca=./tmpdir/pki/ca.crt -ca-key=./tmpdir/pki/ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/kubernetes-admin-csr.json | cfssljson -bare ./tmpdir/pki/kubernetes-admin
openssl rsa  -in ./tmpdir/pki/kubernetes-admin-key.pem -out ./tmpdir/pki/kubernetes-admin.key
openssl x509 -in ./tmpdir/pki/kubernetes-admin.pem -out ./tmpdir/pki/kubernetes-admin.crt

kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt --embed-certs=true --server=https://${KUBE_APISERVER_NAME}:6443 --kubeconfig=./tmpdir/pki/admin.conf
kubectl config set-credentials kubernetes-admin --client-certificate=./tmpdir/pki/kubernetes-admin.crt --client-key=./tmpdir/pki/kubernetes-admin.key --embed-certs=true --kubeconfig=./tmpdir/pki/admin.conf
kubectl config set-context kubernetes-admin@kubernetes --cluster=kubernetes --user=kubernetes-admin --kubeconfig=./tmpdir/pki/admin.conf
kubectl config use-context kubernetes-admin@kubernetes --kubeconfig=./tmpdir/pki/admin.conf

for master_ip in ${MASTER_IPS[@]};
do
  scp -r ./tmpdir/pki/admin.conf root@${master_ip}:/etc/kubernetes/admin.conf;
done

#front-proxy-ca
cat > ./tmpdir/pki/front-proxy-ca-csr.json <<EOF
{
  "CN": "front-proxy-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cfssl gencert -initca ./tmpdir/pki/front-proxy-ca-csr.json | cfssljson -bare ./tmpdir/pki/front-proxy-ca
openssl rsa  -in ./tmpdir/pki/front-proxy-ca-key.pem -out ./tmpdir/pki/front-proxy-ca.key
openssl x509 -in ./tmpdir/pki/front-proxy-ca.pem -out ./tmpdir/pki/front-proxy-ca.crt

for node in ${MASTER_IPS[@]};
do
    scp -r ./tmpdir/pki/front-proxy-ca.key root@${node}:/etc/kubernetes/pki/front-proxy-ca.key;
    scp -r ./tmpdir/pki/front-proxy-ca.crt root@${node}:/etc/kubernetes/pki/front-proxy-ca.crt;
done

#front-proxy-client
cat > ./tmpdir/pki/front-proxy-client-csr.json <<EOF
{
  "CN": "front-proxy-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert -ca=./tmpdir/pki/front-proxy-ca.crt -ca-key=./tmpdir/pki/front-proxy-ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/front-proxy-client-csr.json | cfssljson -bare ./tmpdir/pki/front-proxy-client
openssl rsa  -in ./tmpdir/pki/front-proxy-client-key.pem -out ./tmpdir/pki/front-proxy-client.key
openssl x509 -in ./tmpdir/pki/front-proxy-client.pem -out ./tmpdir/pki/front-proxy-client.crt

#sa
openssl genrsa -out ./tmpdir/pki/sa.key 2048
openssl rsa -in ./tmpdir/pki/sa.key -pubout -out ./tmpdir/pki/sa.pub

for node in ${MASTER_IPS[@]};
do
  scp -r ./tmpdir/pki/front-proxy-client.key root@${node}:/etc/kubernetes/pki/front-proxy-client.key;
  scp -r ./tmpdir/pki/front-proxy-client.crt root@${node}:/etc/kubernetes/pki/front-proxy-client.crt;
  scp -r ./tmpdir/pki/sa.key root@${node}:/etc/kubernetes/pki/sa.key;
  scp -r ./tmpdir/pki/sa.pub root@${node}:/etc/kubernetes/pki/sa.pub;
done

#kube-proxy
cat > ./tmpdir/pki/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-proxy"
    }
  ]
}
EOF

cfssl gencert -ca=./tmpdir/pki/ca.crt -ca-key=./tmpdir/pki/ca.key -config=./tmpdir/pki/ca-config.json -profile=kubernetes ./tmpdir/pki/kube-proxy-csr.json | cfssljson -bare ./tmpdir/pki/kube-proxy
openssl rsa  -in ./tmpdir/pki/kube-proxy-key.pem -out ./tmpdir/pki/kube-proxy.key
openssl x509 -in ./tmpdir/pki/kube-proxy.pem -out ./tmpdir/pki/kube-proxy.crt

kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt --embed-certs=true --server=https://${KUBE_APISERVER_NAME}:6443 --kubeconfig=./tmpdir/pki/kube-proxy.conf
kubectl config set-credentials system:kube-proxy --client-certificate=./tmpdir/pki/kube-proxy.crt --client-key=./tmpdir/pki/kube-proxy.key --embed-certs=true --kubeconfig=./tmpdir/pki/kube-proxy.conf
kubectl config set-context system:kube-proxy@kubernetes --cluster=kubernetes --user=system:kube-proxy --kubeconfig=./tmpdir/pki/kube-proxy.conf
kubectl config use-context system:kube-proxy@kubernetes --kubeconfig=./tmpdir/pki/kube-proxy.conf

if [ ${MASTER_IS_WORKER} = true ]; then
  for node in ${MASTER_IPS[@]} ${NODE_IPS[@]};
  do
    ssh root@${node} "mkdir -p /var/lib/kube-proxy";
    scp -r ./tmpdir/pki/kube-proxy.conf root@${node}:/var/lib/kube-proxy/kubeconfig.conf;
  done
else
  for node in ${NODE_IPS[@]};
  do
    ssh root@${node} "mkdir -p /var/lib/kube-proxy";
    scp -r ./tmpdir/pki/kube-proxy.conf root@${node}:/var/lib/kube-proxy/kubeconfig.conf;
  done
fi

