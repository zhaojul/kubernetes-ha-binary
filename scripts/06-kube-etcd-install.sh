#!/bin/bash
. ./.version
. ./tmpdir/.env
echo ">>>>>> 部署etcd集群 <<<<<<"
rm -rf ./tmpdir/sysconfig
mkdir ./tmpdir/sysconfig

ETCD_INITIAL_CLUSTER_TOKEN=`cat /dev/urandom | head -n 10 | md5sum | head -c 16`

# etcd cluster check
cat > ./tmpdir/etcd-check <<EOF
#!/bin/bash
ETCDCTL_API=3 etcdctl endpoint status \\
   -w table \\
   --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
   --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \\
   --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \\
   --endpoints="https://${MASTER_IPS[0]}:2379,https://${MASTER_IPS[1]}:2379,https://${MASTER_IPS[2]}:2379"
EOF

i=0
for etcd_ip in ${MASTER_IPS[@]};
do
# audo backup settings
cat > ./tmpdir/etcd-snapshot-${etcd_ip} <<EOF
#!/bin/bash

NOWDATE=\`date +%Y-%m-%d\`
OLDDATE=\`date +%Y-%m-%d -d '-15 days'\`
ETCD_SNAPSHOT_DIR="/var/lib/etcd-snapshot"


LIST () {
find \${ETCD_SNAPSHOT_DIR} -type f
}

SAVE() {
[ -d \${ETCD_SNAPSHOT_DIR} ] || mkdir -p \${ETCD_SNAPSHOT_DIR} 
[ -d \${ETCD_SNAPSHOT_DIR}/\${NOWDATE} ] || mkdir \${ETCD_SNAPSHOT_DIR}/\${NOWDATE}
# Automatically clean up snapshot data older than 15 days 
[ ! -d \${ETCD_SNAPSHOT_DIR}/\${OLDDATE} ] || rm -rf \${ETCD_SNAPSHOT_DIR}/\${OLDDATE} 

ETCDCTL_API=3 etcdctl snapshot save \${ETCD_SNAPSHOT_DIR}/\${NOWDATE}/snapshot-\`date +%H:%M:%S\`.db \\
   --cacert=/etc/kubernetes/pki/etcd/ca.crt \\
   --cert=/etc/kubernetes/pki/etcd/server.crt \\
   --key=/etc/kubernetes/pki/etcd/server.key \\
   --endpoints="https://127.0.0.1:2379"
}

RESTORE() {
systemctl stop kube-apiserver.service > /dev/null
systemctl stop etcd.service > /dev/null
LIST
echo "
All etcd snapshots are listed above,
Please select a backup file to restore etcd:
";
read -r  FILE
rm -rf /var/lib/etcd/*
ETCDCTL_API=3 etcdctl snapshot restore \${FILE} \\
--data-dir="/var/lib/etcd" \\
--name ETCD_NAME="${MASTER_NAMES[i]}" \\
--initial-cluster "${MASTER_NAMES[0]}=https://${MASTER_IPS[0]}:2380,${MASTER_NAMES[1]}=https://${MASTER_IPS[1]}:2380,${MASTER_NAMES[2]}=https://${MASTER_IPS[2]}:2380" \\
--initial-cluster-token "${ETCD_INITIAL_CLUSTER_TOKEN}" \\
--initial-advertise-peer-urls "https://${MASTER_IPS[i]}:2380"
}

SHOW_HELP() {
cat << USAGE
usage:
      etcd-snapshot [flags]

      list           List snapshot files in /var/lib/etcd-snapshot directory
      create         Automatically create a snapshot file to the /var/lib/etcd-snapshot directory
      restore        Restoring using an existing snapshot file,
                     All kube-apiserver and etcd services in the Kubernetes cluster must be stopped when restoring snapshots
      help           help for etcd-snapshot

USAGE
exit 0   
}

case "\$1" in
save)
   SAVE
   ;;
restore)
   RESTORE
   ;;
list)
   LIST
   ;;
help|*)  
   SHOW_HELP
   ;;
esac

EOF

echo "0 */6 * * * root /usr/bin/etcd-snapshot save " > ./tmpdir/etcd-snapshot-save


cat > ./tmpdir/sysconfig/etcd-${etcd_ip} <<EOF
ETCD_NAME="${MASTER_NAMES[i]}"
ETCD_ADVERTISE_CLIENT_URLS="https://${MASTER_IPS[i]}:2379"
ETCD_LISTEN_PEER_URLS="https://${MASTER_IPS[i]}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${MASTER_IPS[i]}:2379,https://127.0.0.1:2379"
ETCD_LISTEN_METRICS_URLS="http://0.0.0.0:2381"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${MASTER_IPS[i]}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="${ETCD_INITIAL_CLUSTER_TOKEN}"
ETCD_INITIAL_CLUSTER="${MASTER_NAMES[0]}=https://${MASTER_IPS[0]}:2380,${MASTER_NAMES[1]}=https://${MASTER_IPS[1]}:2380,${MASTER_NAMES[2]}=https://${MASTER_IPS[2]}:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

scp -r ./kube-component/etcd-${ETCD_VERSION}-linux-amd64/etcd root@${etcd_ip}:/usr/bin/etcd
scp -r ./kube-component/etcd-${ETCD_VERSION}-linux-amd64/etcdctl root@${etcd_ip}:/usr/bin/etcdctl
scp -r ./tmpdir/etcd-check root@${etcd_ip}:/usr/bin/etcd-check
scp -r ./tmpdir/etcd-snapshot-${etcd_ip} root@${etcd_ip}:/usr/bin/etcd-snapshot
scp -r ./tmpdir/etcd-snapshot-save root@${etcd_ip}:/etc/cron.d/etcd-snapshot-save
scp -r ./tmpdir/sysconfig/etcd-${etcd_ip} root@${etcd_ip}:/etc/sysconfig/etcd
scp -r ./systemd/etcd.service root@${etcd_ip}:/etc/systemd/system/etcd.service
ssh root@${etcd_ip} "mkdir -p /var/lib/etcd /var/lib/etcd-snapshot /var/log/etcd; chmod 700 /var/lib/etcd /var/lib/etcd-snapshot; chmod 755 /usr/bin/{etcd,etcdctl,etcd-check,etcd-snapshot}; chmod 644 /etc/cron.d/etcd-snapshot-save; systemctl daemon-reload; systemctl restart crond.service;"
let i++
done

for etcd_ip in ${MASTER_IPS[@]};
do
{
ssh root@${etcd_ip} "systemctl enable etcd.service --now; sleep 10s;"
ssh root@${etcd_ip} "systemctl status etcd.service; /usr/bin/etcd-check;"
}&
done
wait

