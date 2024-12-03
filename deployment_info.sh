#!/bin/bash

# 帮助文档
show_help() {
    echo "Usage: $0 [-n NAMESPACE] [-a] [-h] service1 service2 ..."
    echo "Options:"
    echo "  -n NAMESPACE  Specify the namespace to search in."
    echo "  -a            Search in all namespaces (cannot be used with -n)."
    echo "  -h            Show this help message."
    exit 0
}

echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# 已知deployment查询endpoints
deployment_to_endpoints() {
    echo_green "查询endpoints信息..."
    local deploy_json="$1"
    local endpoints=$(echo "$deploy_json" | jq -r '.metadata.annotations."field.cattle.io/publicEndpoints"')

    if [[ $endpoints == "null" ]]; then
        echo "deployment没有暴露端口"
    else
        local num_endpoints=$(echo "$endpoints" | jq -r '. | length')
        echo "共有 $num_endpoints 个 endpoints"

        echo "$endpoints" | jq -c '.[]' | while read -r endpoint; do
            local nodeName=$(echo "$endpoint" | jq -r '.nodeName')
            local serviceName=$(echo "$endpoint" | jq -r '.serviceName')
            local port=$(echo "$endpoint" | jq -r '.port')

            if [[ $nodeName != "null" ]]; then
                echo "这是HostIP, 节点是 $nodeName, 端口是 $port"
            fi

            if [[ $serviceName != "null" ]]; then
                echo "这是NodePort, 服务名称是 $serviceName, 端口是 $port"
            fi
        done
    fi
}

# 已知deployment查询volumes
deployment_to_volumes() {
    echo_green "查询volumes信息..."
    local deploy_json="$1"
    local volumes=$(echo "$deploy_json" | jq -r '.spec.template.spec.volumes')

    if [[ $volumes == "null" ]]; then
        echo "deployment没有挂载卷"
    else
        local num_volumes=$(echo "$volumes" | jq -r '. | length')
        echo "共有 $num_volumes 个 volumes"

        # Kubernetes 支持的volumes类型非常多, 这里只列出了常用的三种
        echo "$volumes" | jq -c '.[]' | while read -r volume; do
            local hostpath=$(echo "$volume" | jq -r '.hostPath')
            local configmap=$(echo "$volume" | jq -r '.configMap')
            local pvc=$(echo "$volume" | jq -r '.persistentVolumeClaim')

            if [[ $hostpath != "null" ]]; then
                local path=$(echo "$hostpath" | jq -r '.path')
                local nodename=$(echo "$deploy_json" | jq -r '.spec.template.spec.nodeName')
                echo "这是HostPath, 节点是 $nodename, 路径是 $path"
            fi

            if [[ $configmap != "null" ]]; then
                local name=$(echo "$configmap" | jq -r '.name')
                echo "这是ConfigMap, 名称是 $name"
            fi

            if [[ $pvc != "null" ]]; then
                local name=$(echo "$pvc" | jq -r '.claimName')
                local annotations=$(kubectl get pvc $name -n $ns -o json | jq '.metadata.annotations')
                local storage=$(echo $annotations | jq '."volume.beta.kubernetes.io/storage-provisioner"')
                echo "这是PersistentVolumeClaim, 名称是 $name"
                if [[ $storage == "openebs.io/local" ]]; then
                    echo "存储类型是openebs.io/local"
                    local selected-node=$(echo $annotations | jq '."volume.kubernetes.io/selected-node"')
                    echo "绑定的节点是 $selected-node"
                else
                    echo "存储类型是 $storage"
                fi
            fi
        done
    fi
}

# 初始化变量
NAMESPACE=""
ALL_NAMESPACES=false
services=()

# 处理命令行参数
while getopts ":n:ah" opt; do
    case $opt in
        n)
            NAMESPACE=$OPTARG
            ;;
        a)
            ALL_NAMESPACES=true
            ;;
        h)
            show_help
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            ;;
    esac
done

# 检查是否安装了 jq
if ! command -v jq &> /dev/null
then
    echo "jq 可能未安装，请先安装 jq。"
    exit 1
fi

# 检查 -n 和 -a 是否冲突
if [[ "$ALL_NAMESPACES" = true && -n "$NAMESPACE" ]]; then
    echo "Options -n and -a cannot be used together."
    exit 1
fi

# 移除已处理的选项参数
shift $(($OPTIND - 1))

# 收集服务名称
services=("$@")

# 如果没有提供服务名称，显示帮助
if [ ${#services[@]} -eq 0 ]; then
    echo "No services specified."
    show_help
fi

# 确定要查询的命名空间
if [ "$ALL_NAMESPACES" = true ]; then
    namespaces=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}')
else
    namespaces=($NAMESPACE)
fi

# 遍历所有命名空间
for ns in ${namespaces[@]}; do
    echo_red "Namespace: $ns"
    # 遍历所有服务名称
    for service in ${services[@]}; do
        # 模糊匹配 Deployment
        deployments=$(kubectl get deployments -n $ns --no-headers | grep -i $service | awk '{print $1}')
        if [ -z "$deployments" ]; then
            echo "               "
            echo "'$ns' 空间中没有找到服务 '$service'"
            continue
        fi
        # 遍历匹配到的 Deployment
        for deploy in $deployments; do
            echo "                   "
            echo_red "Deployment: $deploy"
            deploy_json=$(kubectl get deployment $deploy -n $ns -o json)

            replicas=$(echo $deploy_json | jq -r '.spec.replicas')
            echo "replicas数量是 $replicas"

            echo_green "查询images信息..."
            images=$(echo $deploy_json | jq  '.spec.template.spec.containers|map(.image)[]')  # images is string
            for image in $images; do 
                echo "镜像是 $image";
            done
            deployment_to_endpoints "$deploy_json"
            deployment_to_volumes "$deploy_json"
        done
    done
done
