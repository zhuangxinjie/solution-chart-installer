#!/bin/bash

function show_usage() {
  echo ""
  echo "Usage: bash install.sh [OPTION]"
  echo ""
  echo "Options:"
  echo "    --arch [ARCH]                            CPU架构"
  echo "    --registry [REGISTRY]                    镜像仓库地址，默认使用平台registry"
  echo "    --registry-auth [USERNAME:PASSWORD]      镜像仓库凭据"
  echo "    --namespace [NAMESPACE]                  要部署的命名空间（必选）"
  echo "    --storageclass [STORAGE_CLASS]           要使用的存储类名称（必选）"
  echo ""
}

while [[ $# -gt 0 ]] ; do
    case "$1" in
        --arch) ARCH=$2; shift 2 ;;
        --registry) REGISTRY=$2; shift 2 ;;
        --registry-auth) TARGET_CREDS=$2; shift 2 ;;
        --namespace) NAMESPACE=$2; shift 2 ;;
        --storageclass) STORAGE_CLASS=$2; shift 2 ;;
        --) shift; break ;;
        *)
        echo "Error: "
        echo "    Unknown Options -> $1";
        show_usage
        exit 1
        ;;
    esac
done

if [[ -z $REGISTRY ]]; then
  show_usage
  exit 0
fi

if [[ -z $NAMESPACE ]]; then
  show_usage
  exit 0
fi

if [[ -z $STORAGE_CLASS ]]; then
  show_usage
  exit 0
fi