#!/bin/bash

# ============================================================
#  企业智能知识库 - 以 SkyWalking Agent 启动全部后端服务
# ------------------------------------------------------------
#  位置：knowledge-base-backend/ 仓库根目录（与 pom.xml 同级）。
#        放在这里是为了纳入本仓库的版本控制，
#        不会像外挂脚本那样游离在版本管理之外。
#
#  作用：给每个 Java 微服务挂上 SkyWalking Java Agent，
#        上报调用链路到 OAP；日志里的 [TID:xxx] 即 SkyWalking traceId，
#        可直接拿去 SkyWalking UI 检索同一条链路。
#
#  用法（在 knowledge-base-backend 目录下执行）：
#    ./start-with-skywalking.sh
#
#  关于输出编码：
#    部分终端 / IDE 控制台默认不是 UTF-8（locale 显示 LC_CTYPE=C 等），
#    中文会被解码成 "??" 并且吞掉后续字符。本脚本的**控制台输出已全部使用 ASCII**，
#    在任何终端下都不会乱码；中文只保留在注释里。
#    若你在其它工具里仍看到中文乱码，可执行：
#      export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8
#    （IDEA 用户：Settings -> Tools -> Terminal -> Environment variables 加 LANG=en_US.UTF-8）
#
#  使用前提：
#    1) SkyWalking OAP 可达。项目已有一套远端环境在跑：
#         OAP gRPC = 127.0.0.1:11800（本脚本默认值）
#         UI       = http://127.0.0.1:1080
#       如需本地自建：docker compose -f project/skywalking/docker-compose.yml up -d
#       （自建时 OAP = 127.0.0.1:11800、UI = http://localhost:8180）
#    2) 已下载 SkyWalking Java Agent（版本与 toolkit 一致，当前 9.0.0）。
#
#  可用环境变量：
#    SKYWALKING_AGENT_JAR                 agent jar 路径
#    SW_AGENT_COLLECTOR_BACKEND_SERVICES  OAP 地址，默认 127.0.0.1:11800
#    SW_AGENT_SAMPLE                      采样数，-1 = 全采样（开发建议），默认 -1
#    JAVA_HOME                            默认使用本机 JDK 21
# ============================================================

set -e

# 脚本就放在后端仓库根目录，自身所在目录即后端根目录
BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"

# 项目用 JDK 21（Lombok 与 JDK 25 不兼容）
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"

AGENT_JAR="${SKYWALKING_AGENT_JAR:-$HOME/Downloads/skywalking-agent/skywalking-agent.jar}"
# OAP 地址：默认指向已有的远端 OAP（127.0.0.1:11800），本地自建 OAP 时改回 127.0.0.1:11800
OAP_ADDR="${SW_AGENT_COLLECTOR_BACKEND_SERVICES:-127.0.0.1:11800}"
SAMPLE="${SW_AGENT_SAMPLE:--1}"

# 绿色/黄色/红色
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

echo "======================================"
echo "  Knowledge Base Backend"
echo "  Start with SkyWalking Agent"
echo "======================================"

if [ ! -f "$AGENT_JAR" ]; then
    echo -e "${RED}[ERROR]${NC} SkyWalking Agent not found: $AGENT_JAR"
    echo "  Download the SkyWalking Java Agent and put it there,"
    echo "  or point SKYWALKING_AGENT_JAR to its location."
    exit 1
fi

echo -e "${BLUE}[config]${NC} Agent      : $AGENT_JAR"
echo -e "${BLUE}[config]${NC} OAP        : $OAP_ADDR"
echo -e "${BLUE}[config]${NC} Sample     : $SAMPLE   (-1 = sample all)"
echo -e "${BLUE}[config]${NC} JAVA_HOME  : $JAVA_HOME"
echo ""

# ---------- 插件自检：补齐必需插件 ----------
# SkyWalking 的以下几类插件默认放在 optional-plugins/ 下，**不启用会直接导致链路缺失**：
#   - apm-spring-cloud-gateway-*：网关注册/转发追踪（缺了它网关就没有任何链路）
#   - apm-springmvc-annotation-6.x-*：Spring Boot 3（Spring MVC 6）方法级追踪
#   - apm-mybatis-3.x-*：MyBatis SQL 追踪（可看到慢 SQL）
# 注意：WebFlux 插件（apm-spring-webflux-5.x-plugin）与 Gateway 插件增强的是同一批类
# （DispatcherHandler / ServerWebExchange），两者同时启用会重复埋点，因此这里刻意不启用。
AGENT_DIR="$(cd "$(dirname "$AGENT_JAR")" && pwd)"
REQUIRED_PLUGIN_PATTERNS=(
    # 只启用 3.x（Spring Cloud Gateway 3.x/4.x 都用它）；
    # 2.0.x / 2.1.x 与 3.x 增强同样的类，同时启用会重复埋点，故不启用
    "apm-spring-cloud-gateway-3.x-plugin-*.jar"
    "apm-springmvc-annotation-6.x-plugin-*.jar"
    "apm-mybatis-3.x-plugin-*.jar"
)

for pattern in "${REQUIRED_PLUGIN_PATTERNS[@]}"; do
    # 已在 plugins/ 里（可能通配到多个版本）则跳过
    if ls "$AGENT_DIR/plugins/"$pattern >/dev/null 2>&1; then
        continue
    fi
    # 从 optional-plugins/ 补齐（幂等）
    for src in "$AGENT_DIR/optional-plugins/"$pattern; do
        [ -f "$src" ] || continue
        cp "$src" "$AGENT_DIR/plugins/" && echo -e "${BLUE}[plugin]${NC} enabled $(basename "$src")"
    done
done

# 校验网关插件是否就位（缺失则网关不会被追踪，链路会断在网关）
if ! ls "$AGENT_DIR/plugins/"apm-spring-cloud-gateway-3.x-plugin-*.jar >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN]${NC} Gateway plugin missing -> kb-gateway will NOT be traced"
fi

# 保证 kb-common 的最新代码（含 TraceIdFilter / TraceIdUtil）被安装到本地仓库
echo -e "${BLUE}[prepare]${NC} installing kb-common into local repo ..."
( cd "$BACKEND_DIR" && mvn -o -q install -pl kb-common -am -DskipTests )

# 服务名 -> 端口，仅用于提示
declare -a SERVICES=(
    "kb-gateway:8080"
    "kb-user-auth:8081"
    "kb-document:8082"
    "kb-search:8083"
    "kb-file:8084"
    "kb-statistics:8085"
    "kb-ai:8086"
    "kb-graph:8088"
    "kb-foundation:8089"
)

# 采用 SkyWalking 官方的 SW_AGENT_* 写法（与 agent.config 的占位符一致，同时支持环境变量）
JVM_ARGS="-javaagent:$AGENT_JAR \
-DSW_AGENT_NAME=SERVICE_NAME \
-DSW_AGENT_COLLECTOR_BACKEND_SERVICES=$OAP_ADDR \
-DSW_AGENT_SAMPLE=$SAMPLE"

for item in "${SERVICES[@]}"; do
    svc="${item%%:*}"
    port="${item##*:}"

    if [ ! -d "$BACKEND_DIR/$svc" ]; then
        echo -e "${YELLOW}[WARN]${NC} skip missing module: $svc"
        continue
    fi

    echo -e "${BLUE}[start]${NC} $svc (port $port, service_name=$svc) ..."
    (
        cd "$BACKEND_DIR/$svc"
        mvn spring-boot:run \
            -Dspring-boot.run.jvmArguments="${JVM_ARGS//SERVICE_NAME/$svc}" \
            > "/tmp/$svc.log" 2>&1 &
    )
    sleep 2
done

echo ""
echo -e "${GREEN}[done]${NC} all services launched, logs at /tmp/kb-*.log"
echo ""
echo "Verify tracing:"
echo "  1) call any API, then check the X-Request-Id response header (= traceId)"
echo "  2) grep logs:  grep '<traceId>' logs/kb-gateway/kb-gateway.log"
echo "  3) open SkyWalking UI: http://127.0.0.1:1080"
echo "     (self-hosted OAP -> http://localhost:8180)"
