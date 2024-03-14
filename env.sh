#!/bin/bash

# Nacos 基础配置
NACOS_URL=""
LOGIN_URL="${NACOS_URL}/nacos/v1/auth/login"
NAMESPACES_URL="${NACOS_URL}/nacos/v1/console/namespaces"
SERVICES_URL="${NACOS_URL}/nacos/v1/ns/service/list"

# Nacos 登录凭据
USERNAME=""
PASSWORD=""

# Redis 基础配置
REDIS_HOST=""
REDIS_PORT="6379"
REDIS_PASSWORD=""

# 告警 基础配置
KEY_WX='xxxxxxxxxxxxxxxxxxxxxxxxxx'

# 添加日志函数，用于输出带时间戳和级别的日志信息  
log() {  
    local level=$1  
    local message=$2  
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")  
  
    # 根据日志级别设置颜色（仅警告为红色）  
    local color=""  # 默认颜色  
    if [ "$level" == "ERROR" ]; then  
        color="\033[31m"  # 红色  
        curl 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=${KEY_WX}' -H "Content-Type: application/json;charset=utf-8" -d "{\"msgtype\": \"text\",\"text\": {\"content\":\"[${timestamp}] [level=${level}] ${message}\"}}"
    fi  
  
    echo "[${timestamp}] [level=${level}] ${message}" 
    
}  

# 获取 accessToken  
get_token() {  
    local response=$(curl -s -X POST "$LOGIN_URL" -d "username=$USERNAME&password=$PASSWORD")  
    if [ $? -ne 0 ]; then  
        echo "登录请求失败" >&2  
        exit 1  
    fi  
    echo "$response" | grep -o '"accessToken":"[^"]*"' | awk -F'"' '{print $4}'  
}  

# 获取命名空间
get_namespaces() {
    local token=$1
    local response=$(curl -s -H "Authorization: Bearer $token" "$NAMESPACES_URL")
    if [ $? -ne 0 ]; then
        echo "无法获取命名空间列表" >&2
        exit 1
    fi
    echo "$response" | jq -r '.data[0].namespaceShowName'
}

# 获取服务列表
get_services() {
    local token=$1
    local response=$(curl -s -H "Authorization: Bearer $token" "${SERVICES_URL}?pageNo=1&pageSize=99999")
    if [ $? -ne 0 ]; then
        echo "无法获取服务列表" >&2
        exit 1
    fi
    echo "$response"
}

# 获取服务列表
get_services() {
    local token=$1
    local response=$(curl -s -H "Authorization: Bearer $token" "${SERVICES_URL}?pageNo=1&pageSize=99999")
    if [ $? -ne 0 ]; then
        echo "无法获取服务列表" >&2
        exit 1
    fi
    echo "$response"
}

# 获取特定服务的实例数量
get_service_instances() {
    local token=$1
    local service_name=$2
    local response=$(curl -s -H "Authorization: Bearer $token" "${NACOS_URL}/nacos/v1/ns/instance/list?serviceName=${service_name}")
    if [ $? -ne 0 ]; then
        echo "无法获取服务 ${service_name} 的实例信息" >&2
        return 1
    fi
    echo "$response" | jq -r '.hosts | length'
}

