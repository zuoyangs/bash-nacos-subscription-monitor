#!/bin/bash  

. ./env.sh  

# 将键值对写入 Redis，如果不存在或值不相等  
write_to_redis() {  
    local key=$1
    local value=$2
    local redis_value=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" get "$key" 2>/dev/null)
      
    if [ -z "$redis_value" ] || [ "$redis_value" != "$value" ]; then
        echo "Writing to Redis: $key -> $value"
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" set "$key" "$value"
    else
        echo "redis-server, old_vavlue: $value, new_value: $redis_value"
    fi
}

# 主逻辑  
token=$(get_token)  
if [ -z "$token" ]; then  
    echo "无法从响应中提取 token" >&2  
    exit 1  
fi  
  
namespace=$(get_namespaces "$token")  
echo "nacos_namespace_name: $namespace"  
write_to_redis "nacos_namespace_name" "$namespace"  
  
services_response=$(get_services "$token")  
service_count=$(echo "$services_response" | jq -r '.count')  
echo "nacos_service_count: $service_count"  
write_to_redis "nacos_service_count" "$service_count"  
  
# 读取服务列表并处理每个服务  
service_names=$(echo "$services_response" | jq -r '.doms[]') 
declare -A service_instance_counts  
  
for service_name in $service_names; do  
    instance_count=$(get_service_instances "$token" "$service_name")  
    if [ $? -eq 0 ]; then  
        service_instance_counts[$service_name]=$instance_count  
        sanitized_service_name="${service_name//\//_}"  
        write_to_redis "${sanitized_service_name}" "$instance_count"  
    fi  
done
