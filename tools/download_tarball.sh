#!/bin/bash

RELEASE=`cat ./.release`

DOWNLOAD_TARBALL_URL='https://github.com/kubespaces/kubernetes-ha-install/releases/download'

DOWNLOAD_TARBALL_LIST=(
"kube-component.linux-amd64.tar.gz"
"kube-images-all.linux-amd64.tar.gz"
"kube-rpm-all.linux-amd64.tar.gz"
)

do_download_tarball() {
for tarball in ${DOWNLOAD_TARBALL_LIST[@]};
do
  TARBALL_URL=${DOWNLOAD_TARBALL_URL}/${RELEASE}/${tarball};
  curl -LO ${TARBALL_URL}
done
}

do_download_tarball

