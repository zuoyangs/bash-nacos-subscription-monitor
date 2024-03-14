#!/bin/bash  
  
. ./env.sh
 
# 检查Nacos的namespace是否与Redis中的一致  
check_namespace() {  
    local token=$1  
    local namespace_from_nacos=$(get_namespaces "$token")
    local namespace_from_redis=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" get "nacos_namespace_name" 2>/dev/null) 

    if [ "$namespace_from_nacos" != "$namespace_from_redis" ]; then  
        log ERROR "实例数不匹配, 命名空间: Nacos - $namespace_from_nacos, Redis - $namespace_from_redis"  
    else  
        log INFO "实例数匹配, 命名空间: Nacos - $namespace_from_nacos, Redis - $namespace_from_redis"
    fi  
}  
  
# 检查Nacos的服务总计数是否与Redis中的一致  
check_service_count() {  
    local token=$1
    local services_response=$(get_services "$token")
    local service_count_from_nacos=$(echo "$services_response" | jq -r '.count')
    local service_count_from_redis=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" get "nacos_service_count" 2>/dev/null)  
    
    # 检查变量是否已设置且非空  
    if [ -z "$service_count_from_nacos" ] || [ -z "$service_count_from_redis" ]; then  
        log ERROR "变量 service_count_from_nacos 或 service_count_from_redis 未设置"  
        exit 1  
    fi  
    
    # 比较服务数量  
    if (( service_count_from_nacos < service_count_from_redis )); then 
        echo -n "" #check_service_instances()有逻辑判断，这里就不再写了，重复了"  
    elif (( service_count_from_nacos == service_count_from_redis )); then  
        log INFO "实例总数匹配, Nacos: $service_count_from_nacos, Redis: $service_count_from_redis"  
    elif (( service_count_from_nacos > service_count_from_redis )); then  
        log ERROR "Nacos 新增服务了,需要执行初始化脚本,Nacos: $service_count_from_nacos, Redis: $service_count_from_redis"  
    else  
        echo "错误: 未知的比较结果,Nacos: $service_count_from_nacos, Redis: $service_count_from_redis"  
        exit 1
    fi
}  
  
# 检查每个Nacos服务实例数量与Redis中的是否一致,以及是否有新增或删除的服务  
check_service_instances() {  
    local token=$1  
    local services_response=$(get_services "$token")  
    local service_names=($(echo "$services_response" | jq -r '.doms[]')) # 使用数组来存储服务名称  
    local redis_keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" keys "*" | egrep -v "(nacos_service_count|nacos_namespace_name)")  
      
    declare -A current_service_instance_counts  
    declare -A nacos_service_names # 新增关联数组来存储Nacos中的服务名称  
  
    # 遍历服务名称列表，并在关联数组中记录它们  
    for service_name in "${service_names[@]}"; do  
        if [ -z "$service_name" ]; then  
            log ERROR "在服务列表中遇到空的服务名称。"  
            continue 
        fi  
        # 清理服务名称,替换斜杠为下划线  
        sanitized_service_name="${service_name//\//_}"  
        nacos_service_names[$sanitized_service_name]=1 # 在关联数组中标记服务名称为存在  
    done  
  
    # 遍历Redis keys  
    for redis_key in $redis_keys; do  

        if [[ $redis_key =~ ^[^:]+$ ]]; then  
            if [[ -z ${nacos_service_names[$redis_key]} ]]; then  
                log ERROR "Redis中存在键 $redis_key，但在Nacos中未找到对应的服务。"  
            else  
                # 获取服务实例数（这里假设我们已经有了这个服务名称的清理版本）  
                service_name=${redis_key//_//}  
                instance_count=$(get_service_instances "$token" "$service_name")  
                retrieval_status=$?  
  
                if [ $retrieval_status -eq 0 ] && [ -n "$instance_count" ]; then  

                    # 比较实例数并打印结果  
                    local redis_value=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" get "$redis_key")  
                    if [ "$instance_count" -ne "$redis_value" ]; then  
                        log ERROR "实例数不匹配, 服务 $service_name: Nacos - $instance_count, Redis - $redis_value"  
                    else  
                        log INFO "实例数匹配, 服务 $service_name: Nacos - $instance_count, Redis - $redis_value"  
                    fi  
                else  
                    log ERROR "无法获取服务 $service_name 的实例数"  
                fi  
            fi  
        fi  
    done  
}
  
# 主逻辑  
token=$(get_token)  
if [ -z "$token" ]; then  
    log ERROR "无法从响应中提取 token" >&2  
    exit 1  
fi  
  
# 每隔5秒执行一次检查  
while true; do
    check_namespace "$token"
    check_service_count "$token"
    check_service_instances "$token"
    echo ""
    sleep 5
done
