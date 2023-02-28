# Phoenix User

```
TOKEN=`kubectl get secret -n kube-system \`kubectl get secret -n kube-system | grep phoenix | awk '{print $1}'\` -o jsonpath={.data.token}|base64 -d`
kubectl config set-cluster kubernetes --certificate-authority=./tmpdir/pki/ca.crt --embed-certs=true --server=https://${HAPROXY_IP}:6443 --kubeconfig=phoenix-user.yaml
kubectl config set-credentials phoenix-user --token=${TOKEN} --kubeconfig=phoenix-user.yaml
kubectl config set-context phoenix-user@kubernetes --cluster=kubernetes --user=phoenix-user --kubeconfig=phoenix-user.yaml
kubectl config use-context phoenix-user@kubernetes --kubeconfig=phoenix-user.yaml
```

