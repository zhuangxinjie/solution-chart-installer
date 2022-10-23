#!/bin/bash

CHARTREPO=$1
ACP_DOMAIN=$2
NAMESPACE=$3
CREATE_CHARTREPO=$4
API_TOKEN=$5

CHART_NAME=`ls ./res | grep tgz`

echo CHART_NAME:$CHART_NAME

echo  CHARTREPO:${CHARTREPO},ACP_DOMAIN:${ACP_DOMAIN},NAMESPACE:${NAMESPACE},CREATE_CHARTREPO:${CREATE_CHARTREPO},API_TOKEN:${API_TOKEN}
script_dir=$(cd $(dirname $0);pwd)

echo dir:${script_dir}

#创建 chart_repo
create_chart_repo() {
  echo "开始创建 chart 仓库"
  curl -k --request POST \
    --url https://$ACP_DOMAIN/catalog/v1/chartrepos \
    --header 'Authorization:Bearer '$API_TOKEN’ \
    --header 'Content-Type: application/json' \
    --data '{
      "apiVersion": "v1",
      "kind": "ChartRepoCreate",
      "metadata": {
        "name": "'${CHARTREPO}'",
        "namespace": "'${NAMESPACE}'"
      },
      "spec": {
        "chartRepo": {
          "apiVersion": "app.alauda.io/v1beta1",
          "kind": "ChartRepo",
          "metadata": {
            "name": "'${CHARTREPO}'",
            "namespace": "'${NAMESPACE}'",
            "labels": {
              "project.cpaas.io/catalog": "true"
            },
            "annotations": {
              "cpaas.io/description": ""
            }
          },
          "spec": {
            "type": "Local",
            "url": null,
            "source": null
          }
        },
        "secret": null
      }
    }'
  echo "chart 仓库创建成功"
}
# # 上传 chart 包
upload_chart() {
  echo "开始上传chart"
  curl -k --request POST \
  > --url https://$ACP_DOMAIN/catalog/v1/chartrepos/${NAMESPACE}/${CHARTREPO}/charts \
  > --header 'Authorization:Bearer '$API_TOKEN \
  > --data-binary @"${script_dir}/res/${CHART_NAME}"
  {
  "name": "solution-chart",
  "version": "1.0.1",
  "description": "A Helm chart for Kubernetes",
  "apiVersion": "v2",
  "appVersion": "1.0.1",
  "type": "application"
  }
  echo "上传chart结束"
}

upload_chart_operator(){

  if [ $CREATE_CHARTREPO == "true" ];
    then
    echo "执行create_chart_repo 方法 "
    create_chart_repo
  fi
  upload_chart
}

upload_chart_operator
