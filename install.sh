#!/bin/bash
LANG=zh_CN.UTF-8

HARBORURL=192.168.184.20:32071
HARBORUSERNAME=admin
HARBORPASSWORD=Harbor12345
CHARTREPO=test1
ACPURL=192.168.182.141
NAMESPACE=chuangxing
CREATE_CHARTREPO=true   # 如果已存在char仓库 就不需要再创建  填 false 。如果不存在 填 true
TOKEN=eyJhbGciOiJSUzI1NiIsImtpZCI6ImJhMTg0YzlmYjE5OWExMGNmYTRlYTE3ZjQyNTI5Y2I5MzdjNmRiMDQiLCJ0eXAiOiJKV1QifQ.eyJqdGkiOiI5YjdmNTRiZi1lMzY5LTQzNGQtOGJjZi1lNGRkZWJlNWU0NDYiLCJpYXQiOjE2NjYzNTA5NDUsInR5cCI6IkFjY2Vzc1Rva2VuIiwiZW1haWwiOiJhZG1pbkBjcGFhcy5pbyJ9.CCkVZ3tl23XDuxcxlJbnyjr3qvdNBMnhlx2_UuOLhQUr4pw8WLeyflc_KXmhMo5pCp6q3tVnZ_MxCi7kdsn1iJEDAoZbNQxMpCyXEEaNEF1dXJmpgSyX7ffeA3ddYvRTJvM-AFpyTMwOys_QKlCxl4QkUCAfqh4ZXSoDayPFPXJyz4l8kEbDohkSiR6emLApEZrB_m04NE7X5nc9wWtOXB4oPfVokgNsdEnIiG33p9HSSlt_TUMaDptKtWTamRIvhXoRyZhv2HdpbfJFomIOZ2mjvLUWa2r2W_FDPyKfMFY9R740BAlWwv28lFEgu8KuoOUm1rH-74TXZZcgYf_Psw

echo harborurl：${HARBORURL},harborusername:${HARBORUSERNAME},harborpassword:${HARBORPASSWORD},chartrepo：${CHARTREPO},acpurl:${ACPURL},namespace:${NAMESPACE},token:${TOKEN},CREATE_CHARTREPO:${CREATE_CHARTREPO}

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
REGISTRY=${HARBORURL}
#NAMESPACE="cpaas-system"
STORAGE_CLASS=""
ARCH="arm"
TARGET_CREDS=""
TARGET_INSECURE="false"
TARGET_PLAIN_HTTP="true"

script_dir=$(cd $(dirname $0);pwd)
# #. $script_dir/res/show-usage.sh

# whether registry has auth

if [ $? == 0 ]; then
    REGISTRY_USERNAME=${HARBORUSERNAME}
    REGISTRY_PASSWORD=${HARBORPASSWORD}
    TARGET_CREDS=$(echo -n "$REGISTRY_USERNAME:$REGISTRY_PASSWORD" | base64 -w 0)
    TARGET_INSECURE="true"
    TARGET_PLAIN_HTTP="false"
    docker login ${REGISTRY} -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} > /dev/null 2>&1
fi


REGISTRY_IMAGE="$REGISTRY/ait/registry:2"

REGISTRY_OPTIONS="-d --restart=always --name upgrade-registry

-p 1234:5000
-v $(pwd)/registry:/var/lib/registry
"

SYNC_IMAGE_VERSION="v3.0.4"

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



停止运行临时registry
function clean_up() {
#    kubectl get apprelease -l customization=true -n $NAMESPACE
    docker rm -f upgrade-registry
}

start_registry
start_sync_image

 . $script_dir/res/pre-install.sh  ${CHARTREPO} ${ACPURL} ${CREATE_CHARTREPO} ${TOKEN} // 调用应用商店接口，上传chart包
# #start_deploy_app_release

# clean_up
. $script_dir/res/post-install.sh
