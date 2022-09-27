#!/bin/bash

#部署 amq operator
function install_activemq_operator() {
  export NAME="activemq-operator"                            # 名称
  export DISPLAYNAME="activemq-operator"                     # 页面展示名称
  export DESCRIPTION="activemq operator bundle images"       # 描述
  export REPOSITORY="solutions/activemq-operator-bundle"           # 仓库项目路径
  export VERSION="v1.0.24" # 版本号

  k_num=$(kubectl get Artifact -n ${NAMESPACE} --ignore-not-found --no-headers ${NAME}|wc -l)

  if [ $k_num -le 0 ]; then

cat << EOF | kubectl create -f -
apiVersion: app.alauda.io/v1alpha1
kind: Artifact
metadata:
  name: ${NAME}
  namespace: cpaas-system
  labels:
    cpaas.io/library: platform
spec:
  artifactVersionSelector:
    matchLabels:
      cpaas.io/artifact-version: ${NAME}
  displayName: ${DISPLAYNAME}
  description: ${DESCRIPTION}
  registry: ${REGISTRY}
  repository:  ${REPOSITORY}
  type: bundle
  present: true
  imagePullSecrets:
    - default
EOF
    
  fi

  chmod +x res/kubectl-artifact-${ARCH}
  cp res/kubectl-artifact-${ARCH} $(dirname $(which kubectl))/kubectl-artifact

  kubectl artifact createVersion --artifact ${NAME}  --tag="${VERSION}" --namespace cpaas-system

  kubectl get artifactversion -A | grep  ${NAME}

  kubectl get pod -A | grep catalog | awk '{print "kubectl delete pod -n ", $1, $2}' | bash


  PM=$(kubectl get PackageManifest --ignore-not-found --no-headers|grep ${NAME})
  while [ "$PM" = "" ]
  do
    echo "${NAME}.${VERSION}上架中，请等待。。。"
    sleep 3
    PM=$(kubectl get PackageManifest --ignore-not-found --no-headers|grep ${NAME})
  done

EXISTS_KEY=$(kubectl get resourcepatch --ignore-not-found operator-images-${NAME}-patch)
  if [ "$EXISTS_KEY" ]; then
    echo "resourcepatch operator-images-${NAME}-patch exists...ignored."
  else
    echo 'Patching operator-images...'
    kubectl get cm -o yaml -n cpaas-system operator-images>/tmp/operator-images.yaml
    sed -i '0,/^.*images\.yaml:/d' /tmp/operator-images.yaml
    sed -i '/^kind: ConfigMap$/,$d' /tmp/operator-images.yaml
    sed -i 's/^/    /' /tmp/operator-images.yaml

cat <<EOF > /tmp/resource-patch.yaml
apiVersion: operator.alauda.io/v1alpha1
kind: ResourcePatch
metadata:
  finalizers:
    - resourcepatch
  name: operator-images-${NAME}-patch
spec:
  jsonPatch:
    - op: replace
      path: /data/images.yaml
      value: |
EOF
  cat /tmp/operator-images.yaml>>/tmp/resource-patch.yaml
cat <<EOF >> /tmp/resource-patch.yaml
          activemq:
            - build-harbor.alauda.cn/solutions/activemq-operator:v1.0.11
            - build-harbor.alauda.cn/solutions/zookeeper:v3.8.0
            - build-harbor.alauda.cn/solutions/activemq:v5.15.4
  release: cpaas-system/olm
  target:
    apiVersion: v1
    kind: ConfigMap
    name: operator-images
    namespace: cpaas-system
EOF
cat <<EOF >> /tmp/resource-patch.yaml
  release: cpaas-system/olm
  target:
    apiVersion: v1
    kind: ConfigMap
    name: operator-images
    namespace: cpaas-system
EOF
  kubectl apply -f /tmp/resource-patch.yaml || echo 'operator-images Patched'
  fi

  echo "${NAME}.${VERSION}上架完成 【OK】"

}

install_activemq_operator
