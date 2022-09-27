#!/bin/bash
LANG=zh_CN.UTF-8

set -o nounset
set -o pipefail

umask 0022
unset IFS
unset OFS
unset LD_PRELOAD
unset LD_LIBRARY_PATH

export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

TEMP=`getopt -o a --long arch:,registry:,registry-auth:,namespace:,storageclass: -- "$@"`
eval set -- "$TEMP"
REGISTRY=$(kubectl get cm -n kube-public global-info  -o yaml |  awk '/^  registryAddress:/{print $NF}')
NAMESPACE="cpaas-system"
STORAGE_CLASS=""
ARCH="arm"
TARGET_CREDS=""
TARGET_INSECURE="false"
TARGET_PLAIN_HTTP="true"

script_dir=$(cd $(dirname $0);pwd)
#. $script_dir/res/show-usage.sh

# whether registry has auth
cat /etc/kubernetes/manifests/registry.yaml | grep "/etc/kubernetes/registry/auth.yaml" > /dev/null 2>&1
if [ $? == 0 ]; then
    REGISTRY_ADMIN=$(kubectl get secret -n cpaas-system registry-admin > /dev/null 2>&1)
    REGISTRY_USERNAME=$(kubectl get secret -n cpaas-system registry-admin -o jsonpath='{.data.username}' | base64 -d)
    REGISTRY_PASSWORD=$(kubectl get secret -n cpaas-system registry-admin -o jsonpath='{.data.password}' | base64 -d)
    TARGET_CREDS=$(echo -n "$REGISTRY_USERNAME:$REGISTRY_PASSWORD" | base64 -w 0)
    TARGET_INSECURE="true"
    TARGET_PLAIN_HTTP="false"
    docker login ${REGISTRY} -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} > /dev/null 2>&1
fi

REGISTRY_VERSION=$(cat /etc/kubernetes/manifests/registry.yaml|sed -nr 's/^.*registry:(.*)$/\1/p')

REGISTRY_IMAGE="$REGISTRY/ait/registry:$REGISTRY_VERSION"
REGISTRY_OPTIONS="-d --restart=always --name upgrade-registry
-p 1234:5000
-v $(pwd)/registry:/var/lib/registry
"

SYNC_IMAGE_VERSION="v3.0.2"

function get_arch() {
  os_arch=$(uname -m)
  if [[ "$os_arch" =~ "x86" ]]
  then
    ARCH="x86"
  elif [[ "$os_arch" =~ "aarch" ]]
  then
    ARCH="arm64"
  fi
}

#启动临时registry
function start_registry() {
  echo "启动临时registry于端口1234"
  get_arch

  ur=$(docker ps |grep upgrade-registry|wc -l)
  if [ $ur -eq "1" ]
  then
    docker rm -f upgrade-registry
  fi

  docker run $REGISTRY_OPTIONS ${REGISTRY_IMAGE}
  sleep 5
  echo "registry启动成功"

}

#同步镜像
function start_sync_image() {
    echo "开始同步镜像"

    docker run -ti --net host  -v $(pwd)/res:/res -v /var/run/docker.sock:/var/run/docker.sock $REGISTRY/ait/sync_image:${SYNC_IMAGE_VERSION} python sync_image.py $REGISTRY "$TARGET_CREDS" $TARGET_INSECURE $TARGET_PLAIN_HTTP

    echo "同步镜像成功"
}

##部署apprelease
# function start_deploy_app_release() {
#     echo "部署app release"
    
#     sed -i "s/DEST_NAMESPACE/$NAMESPACE/g" res/apprelease/*
#     sed -i "s/REGISTRY/$REGISTRY/g" res/apprelease/*
#     sed -i "s/STORAGE_CLASS/$STORAGE_CLASS/g" res/apprelease/*
#     kubectl apply -f res/apprelease -n $NAMESPACE
#     sleep 1
#     all_num=$(kubectl get apprelease -l customization=true -n $NAMESPACE --ignore-not-found|wc -l)
#     all=$((all_num - 1))
#     release_name=$(grep 'name: .*' res/apprelease/*|head -n 1 |awk '{print $2}')
#     while true
#     do
#         ready_num=$(kubectl get apprelease $release_name -n $NAMESPACE --ignore-not-found| grep -w Ready| wc -l)
#         ready=$((ready_num))
#         if [ $ready -eq $all ]
#         then
#             echo "部署完成！"
#             echo "****** $release_name ******"
#             kubectl get po -l app.kubernetes.io/instance=$release_name -n $NAMESPACE
#             break
#         else
#             kubectl get apprelease $release_name -n $NAMESPACE| grep -vw Ready
#             echo "部署中，请等待"
#             echo "****** $release_name ******"
#             kubectl get po -l app.kubernetes.io/instance=$release_name -n $NAMESPACE
#             sleep 3
#         fi
#     done

# }

#停止运行临时registry
function clean_up() {
    kubectl get apprelease -l customization=true -n $NAMESPACE
    docker rm -f upgrade-registry
}

start_registry
start_sync_image
. $script_dir/res/pre-install.sh   // 调用应用商店接口，上传chart包
#start_deploy_app_release
clean_up
. $script_dir/res/post-install.sh
