# DevOps

本仓库集中维护 OMS 相关项目的 Docker 开发环境与部署配置，涵盖 PHP / Hyperf 运行环境、数据库与中间件、APISIX 网关、FastGPT 服务栈，以及 Java 应用镜像构建模板。

各模块独立构建或启动，业务代码由外部项目提供。仓库根目录没有统一的 Compose 文件，也没有自动完成所有服务初始化的部署脚本。下文按当前 Dockerfile、Compose 和插件实现说明使用方式；模块内的历史 README 可能与当前配置不同。

## 项目结构

| 目录 | 主要文件 | 用途 |
| --- | --- | --- |
| [`php82-swool5-17/`](php82-swool5-17/) | `docker-compose.yml`、`docker-file/Dockerfile`、`Dockerfile-xdebug` | PHP / Swoole 开发容器及可选 Xdebug 镜像 |
| [`middleware-and-database/`](middleware-and-database/) | `docker-compose.yml`、`.env`、`database/mysql/` | 数据库、中间件、向量存储及管理工具 |
| [`gateway/docker/`](gateway/docker/) | `docker-compose.yaml`、`config.yaml`、`plugins/umc-auth.lua` | APISIX 网关与 UMC 鉴权插件 |
| [`fastgpt/`](fastgpt/) | `docker-compose.yaml` | 复用现有中间件的 FastGPT 部署栈 |
| [`java/`](java/) | `Dockerfile` | Java 21 / Spring Boot 多阶段镜像模板 |

## 使用前准备

- 安装并启动 Docker，使用 `docker compose` 命令。FastGPT 使用内嵌 `configs.content`，Compose 版本需支持该功能。
- 准备当前机器可写的数据、项目和日志目录，修改配置中的本机路径。
- 按实际环境设置账号、密码和密钥；本文不复写仓库中的现有凭据。
- 按需启动服务。网关和 FastGPT 依赖中间件创建的 `middleware-db_middleware-sail` 网络；PHP 默认使用自己的网络。

除特别说明外，以下命令均在仓库根目录执行。

### 默认端口与冲突

端口均为宿主机端口；带变量的映射可在对应配置中调整。

| 模块 / 服务 | 默认端口 | 说明 |
| --- | --- | --- |
| PHP / Hyperf | `80 → 9501`、`9502`、`9503` | `APP_PORT` 控制宿主机 80 映射到的容器端口 |
| MySQL | `3306` | `DB_PORT` |
| Redis | `6379` | `REDIS_PORT` |
| Elasticsearch | `127.0.0.1:9200` | `ES_PORT`，仅绑定本机回环地址 |
| RabbitMQ | `5672`、`15672` | AMQP、管理页面 |
| MongoDB | `27017` | `MONGO_DB_PORT` |
| etcd | `2379`、`2380` | 客户端、节点通信 |
| PostgreSQL / pgvector | `5432` | `POSTGRES_PORT` |
| MinIO | `9000`、`9001` | S3 API、管理控制台 |
| Milvus | `19530`、`9091` | gRPC、健康检查 / 监控 |
| Attu | `3000` | Milvus 管理页面 |
| APISIX | `9080`、`9443`、`9180`、`9091` | HTTP、HTTPS、管理接口与内置 UI、监控端口映射 |
| FastGPT | `3000`、`3003`、`3006` | 应用、MCP 服务、Agent 沙箱代理 |

同时使用相关模块前，需要调整以下映射：

- **Attu 与 FastGPT** 都使用 `3000`。可只启动所需服务，或修改其中一方的宿主机端口。
- **Milvus 与 APISIX** 都发布 `9091`。可将 APISIX 的映射改为 `19091:9091`，或移除不需要的监控端口映射。
- 旧版独立 Dashboard 配置使用 `9000`，与 **MinIO** 冲突。当前网关主配置使用内置 UI。

## 数据库与中间件

配置入口：[docker-compose.yml](middleware-and-database/docker-compose.yml)、[.env](middleware-and-database/.env)。

### 服务组成

| Compose 服务名 | 镜像 / 版本 | 主要用途 |
| --- | --- | --- |
| `mysql` | `mysql:8.0` | 关系型数据库，挂载自定义 SQL mode 和初始化脚本 |
| `redis` | `redis:alpine` | 带密码的缓存服务 |
| `es` | Elasticsearch `${ES_VERSION:-9.5.5}` | 单节点搜索服务，关闭安全认证 |
| `rabbit-mq` | `rabbitmq:3.13-management` | 消息队列及 Web 管理界面 |
| `mongo-db` | `mongo:8.0` | 配置为 `rs0` 副本集的 MongoDB |
| `etcd` | `quay.io/coreos/etcd:v3.7.0` | APISIX 配置存储及 Milvus 依赖 |
| `pgvector` | `pgvector/pgvector:pg16` | PostgreSQL 16，提供 pgvector 扩展镜像 |
| `minio` | `minio/minio:latest` | 对象存储 |
| `milvus` | `milvusdb/milvus:v3.0.3` | 启用鉴权的 standalone 向量数据库，依赖 etcd 和 MinIO |
| `attu` | `zilliz/attu:v3.0.0` | Milvus 可视化管理工具 |

### 环境配置

修改 `middleware-and-database/.env`，重点核对以下变量：

| 配置项 | 用途 |
| --- | --- |
| `DATA_PATH` | 宿主机数据目录，需替换为当前机器的绝对路径 |
| `DB_PORT`、`MYSQL_DB_DATABASE` | MySQL 端口和初始化数据库名 |
| `DB_ROOT_PASSWORD`、`MYSQL_OPS_USERNAME`、`MYSQL_OPS_PASSWORD` | MySQL root 与业务账号配置 |
| `REDIS_PORT`、`REDIS_PASSWORD` | Redis 端口和密码 |
| `ES_VERSION`、`ES_PORT`、`ES_JAVA_OPTS`、`ES_MEMORY_LIMIT` | Elasticsearch 版本、端口、JVM 和容器内存配置 |
| `RABBIT_MQ_CLIENT_PORT`、`RABBIT_MQ_WEB_PORT`、`RABBIT_MQ_USER`、`RABBIT_MQ_PASSWORD` | RabbitMQ 端口和账号 |
| `MONGO_DB_PORT`、`MONGO_DB_USER`、`MONGO_DB_PASSSWORD` | MongoDB 端口和账号；密码变量名实际包含三个 `S` |
| `POSTGRES_PORT`、`POSTGRES_PASSWORD` | PostgreSQL 端口和密码 |
| `MINIO_ROOT_PASSWORD` | MinIO 密码，同时供 Milvus 访问 MinIO 使用 |
| `MILVUS_ROOT_PASSWORD`、`MILVUS_MEMORY_LIMIT`、`MILVUS_MEMORY_RESERVATION`、`MILVUS_LOG_LEVEL` | Milvus 鉴权、资源和日志配置 |

### 按需启动

例如，仅启动 PHP 项目常用的 MySQL、Redis 和 RabbitMQ：

```bash
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml up -d mysql redis rabbit-mq
```

仅为 APISIX 准备 etcd 和共享网络：

```bash
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml up -d etcd
```

完成所需初始化并处理端口冲突后，可启动全部中间件：

```bash
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml up -d
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml ps
```

### 初始化与数据目录

- **MySQL**：首次初始化空数据目录时，创建配置的业务数据库和账号；额外脚本创建 `testing` 数据库，并授予业务账号对 `testing%` 数据库的权限。自定义 SQL mode 未包含 `ONLY_FULL_GROUP_BY`。已有数据目录不会重新执行初始化脚本。
- **MongoDB**：启动命令要求 `/data/db/mongodb.key`。首次启动前，需在 `${DATA_PATH}/mongo-data/mongodb.key` 准备有效的副本集 keyfile，并设置为容器内 MongoDB 用户可读、符合 MongoDB 限制的属主和权限。仓库没有生成 keyfile 或初始化副本集的脚本。
- **PostgreSQL**：当前配置仅初始化 `fastgpt` 数据库；FastGPT 的 AIProxy 另需 `aiproxy` 数据库。
- **持久化**：多数中间件的数据挂载到 `${DATA_PATH}` 下的服务子目录。RabbitMQ 当前只挂载 `/data`、`/myplugins`，未将默认数据目录 `/var/lib/rabbitmq` 挂到宿主机；若需保留队列数据，应先调整该挂载。
- **Attu 网络**：当前 Attu 使用 Compose 默认网络，未加入共享中间件网络。连接 Milvus 时需填写它能访问的地址，或将其加入 `middleware-db_middleware-sail` 后使用 `milvus:19530`。

MongoDB 成功启动后，可进入交互式 Shell，按提示输入密码；若修改过用户名，请同步替换 `root`：

```bash
docker exec -it mongodb mongosh --username root --password --authenticationDatabase admin
```

仅在尚未初始化 `rs0` 时执行以下 MongoDB Shell 命令：

```javascript
rs.initiate({ _id: "rs0", members: [{ _id: 0, host: "mongodb:27017" }] })
rs.status()
```

等待节点成为可写主节点，再启动依赖副本集的应用。

## PHP / Hyperf 开发环境

默认构建使用 [Dockerfile](php82-swool5-17/docker-file/Dockerfile)，基于 **PHP 8.2.35 / Alpine 3.20**，安装 **Swoole 5.1.7**、Redis 扩展 6.1.0、Composer，以及 MySQL / PostgreSQL PDO、GD、ZIP、OPcache、PCNTL、Sockets、SOAP、igbinary、msgpack、xlswriter 等扩展。时区为 `Asia/Shanghai`，关闭 Swoole 短名。

### 配置并启动容器

新建 `php82-swool5-17/.env`，按本机目录填写：

```dotenv
BASE_PROJECT_PATH=/absolute/path/to/projects
PROJECT_NAME=your-hyperf-project
LOG_DIR=/absolute/path/to/logs
APP_ENV=dev
APP_PORT=9501
```

`BASE_PROJECT_PATH` 挂载到 `/webser/www/`，工作目录为 `/webser/www/${PROJECT_NAME}`，因此宿主机上必须存在 `${BASE_PROJECT_PATH}/${PROJECT_NAME}` 项目目录。`LOG_DIR` 挂载到 `/webser/logs/`；请先创建日志目录及其 `php` 子目录，PHP 错误日志写入 `php/php_error.log`。

```bash
docker compose --env-file php82-swool5-17/.env -p xzy -f php82-swool5-17/docker-compose.yml up -d --build
```

Compose 服务名为 `oms-hyperf`，容器名为 `base-svc`。默认入口为 `tail -f /dev/null`，上述命令仅构建并保持开发容器运行。业务项目需另行安装依赖、启动 Hyperf：

```bash
docker compose --env-file php82-swool5-17/.env -p xzy -f php82-swool5-17/docker-compose.yml exec oms-hyperf composer install
docker compose --env-file php82-swool5-17/.env -p xzy -f php82-swool5-17/docker-compose.yml exec oms-hyperf php bin/hyperf.php start
```

第二条命令在前台运行 Hyperf。需要随容器自动启动时，可将 Compose 的 `entrypoint` 改为业务启动命令。`APP_PORT` 只改变端口映射的容器端口，应用自身的监听端口需保持一致。

### 网络与可选配置

PHP 容器使用独立网段 `172.169.0.0/24`，固定 IP 为 `172.169.0.21`。若需使用中间件的容器名访问数据库，可在两组容器启动后连接共享网络：

```bash
docker network connect middleware-db_middleware-sail base-svc
```

该连接在容器重建后需重新执行；长期使用时，应在 PHP Compose 中声明并加入外部网络。应用连接中间件时使用容器端口，例如 `mysql:3306`、`redis:6379`。Compose 的 `extra_hosts` 仅作用于容器内部，宿主机使用本地域名时需自行配置解析。

- **Xdebug**：将 `build.dockerfile` 改为 `Dockerfile-xdebug` 后重新构建。该文件使用 PHP 8.2.27 / Swoole 5.1.7，调试连接指向 `host.docker.internal:9003`，需在 IDE 配置监听和路径映射。
- **Nginx / Supervisor**：仓库保留了 Nginx HTTP / WebSocket 代理示例和 `scripts/start.sh`。当前镜像没有安装、启动 Nginx 或 Supervisor，启动脚本也未接入默认流程。
- **PHP 内存**：`conf/php.ini` 当前设置 `memory_limit=64M`，可按业务需求修改后重新构建。

## APISIX 网关与 UMC 鉴权

主配置为 [docker-compose.yaml](gateway/docker/docker-compose.yaml)，使用 **APISIX 3.17.0**，挂载 `config.yaml` 和自定义 `umc-auth.lua`。网关连接共享网络中的 `etcd:2379`，路由等动态配置存储在 etcd。

先启动 etcd、处理与 Milvus 的 `9091` 端口冲突，再启动网关：

```bash
docker compose -p apisix -f gateway/docker/docker-compose.yaml up -d
```

- HTTP 网关：`http://127.0.0.1:9080`
- HTTPS 网关端口：`9443`，证书及路由需另行配置。
- 按当前管理监听配置，内置 UI 入口为 `http://127.0.0.1:9180/ui/`，使用 `config.yaml` 中 `deployment.admin.admin_key` 配置的密钥。

仓库没有预置业务路由，启动后需通过管理 UI 或 Admin API 配置路由、上游及插件。当前管理接口发布到宿主机所有地址，`allow_admin` 也允许所有来源，部署时应按访问范围修改监听、端口绑定及密钥。

`docker-compose-dashboard.yaml`、`dashboard.yaml` 是保留的独立 Dashboard 配置，不属于上述主启动流程；该 Compose 也未挂载 `umc-auth.lua`。`config.init.yaml` 是最小 etcd 配置，主 Compose 未引用它。

### `umc-auth` 插件行为

在需要鉴权的路由上启用插件，例如：

```json
{
  "umc-auth": {
    "uri": "https://your-umc.example.com/umc/user/auth",
    "ssl_verify": true,
    "timeout": 3000,
    "status_on_error": 503,
    "allow_degradation": false
  }
}
```

上例为路由 `plugins` 字段的内容；若在 UI 中编辑单个插件，仅填写内部配置对象。

插件向 `uri` 发起 **GET** 鉴权请求，并从原始请求提取以下查询参数：

| 参数 | 含义 | 请求 `POST /oms/order/list?page=1` 的结果 |
| --- | --- | --- |
| `gateway_prefix` | 路径的第一段 | `oms` |
| `router` | 去掉第一段前缀的路径，不含查询参数 | `/order/list` |
| `method` | 小写的原始 HTTP 方法 | `post` |

插件向 UMC 转发 `Cookie` 和 `X-Forwarded-*` 请求头，不向 UMC 转发客户端的 `Authorization`。`gateway_prefix` 自动从路径提取，无需作为插件配置填写。

- UMC 返回 `200` 时放行，可用 `upstream_headers` 将指定的 UMC 响应头写入业务请求。
- UMC 返回其他状态时，将该状态码和响应体返回客户端，可用 `client_headers` 指定透传的响应头。
- UMC 网络请求失败时，默认返回 `503`；`allow_degradation=true` 仅对此类请求失败放行。
- 单段路径（如 `/oms`、`/oms/`）以及以 `/` 结尾的双段路径（如 `/oms/platform/`）直接返回 `200 hello world`。
- 未命中上述直接响应规则时，最后一段为 `health` 的路径跳过鉴权并继续转发，例如 `/oms/health`、`/oms/platform/health/`。`/health`、`/oms/health/` 则会先命中前缀规则，直接返回 `hello world`。

去前缀路径仅用于 UMC 鉴权参数；插件不修改转发到业务服务的 URI。业务若需要去掉前缀，应另行配置路由重写。

## FastGPT 服务栈

[fastgpt/docker-compose.yaml](fastgpt/docker-compose.yaml) 部署 FastGPT 应用、插件、模型代理和沙箱服务，复用共享网络中的 MongoDB、Redis、PostgreSQL、MinIO 和 Milvus。

| 服务 | 配置版本 | 用途 |
| --- | --- | --- |
| `fastgpt-app` | `v4.15.8` | FastGPT 主应用，发布 `3000` |
| `fastgpt-plugin` | `v1.0.3` | 插件服务 |
| `fastgpt-code-sandbox` | `v4.15.7` | JS / Python 代码执行沙箱 |
| `fastgpt-aiproxy` | `v0.6.5` | 模型访问代理，使用 PostgreSQL `aiproxy` 数据库 |
| `fastgpt-mcp-server` | `v4.14.23` | MCP 服务，发布 `3003` |
| `fastgpt-opensandbox-server` | `v0.2.0` | 管理 Docker 运行时沙箱 |
| `fastgpt-volume-manager` | `v0.2.0` | Agent 沙箱卷管理 |
| `fastgpt-agent-sandbox-proxy` | `v0.2.0` | Agent 沙箱代理，发布 `3006` |

### 启动前对接

1. 准备 MongoDB keyfile，启动并初始化 `rs0`；确认共享网络可用。MongoDB 连接要求 `replicaSet=rs0`，应用和插件分别使用 `fastgpt`、`fastgpt-plugin` 数据库。
2. 核对 Compose 顶部的数据库、对象存储、向量库和内部服务密钥配置。FastGPT 的连接串与凭据直接配置在该文件中，不会自动读取中间件 `.env`；当前 Redis 密码和 Milvus token 与中间件配置不一致，需同步修改。连接串中的特殊字符需正确编码。
3. 在 PostgreSQL 中创建 `aiproxy` 数据库；仅在数据库尚不存在时执行下方建库命令。
4. 核查 MinIO 的 `fastgpt-public`、`fastgpt-private` 存储桶及访问权限。仓库没有独立建桶脚本。
5. 停用 Attu 或调整端口映射，避免占用 `3000`。远程访问时同步修改 `FE_DOMAIN`、MCP 公开地址和 Agent WebSocket 地址，默认值均指向本机。

启动 FastGPT 所需中间件，不启动 Attu：

```bash
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml up -d mongo-db redis pgvector minio milvus
```

Milvus 会同时带起 etcd。MongoDB 副本集初始化方式见前文。PostgreSQL 启动后，创建 AIProxy 数据库：

```bash
docker exec -it pgvector psql -U postgres -d postgres -c 'CREATE DATABASE aiproxy;'
```

完成对接后，可预拉取沙箱镜像，再启动应用栈：

```bash
docker compose -f fastgpt/docker-compose.yaml --profile prepull pull
docker compose -f fastgpt/docker-compose.yaml up -d
docker compose -f fastgpt/docker-compose.yaml ps
```

`prepull` profile 中的三个服务仅用于准备 Agent 沙箱、execd 和 egress 镜像，正常 `up` 不需要启用此 profile。应用等待代码沙箱、插件、AIProxy 健康后启动，MCP 服务等待应用健康。

浏览器访问 `http://localhost:3000`；默认 root 密码由 `x-default-root-psw` 配置。OpenSandbox 和卷管理器挂载了宿主机 Docker socket，运行环境需允许它们管理沙箱资源。

## Java 镜像构建模板

[java/Dockerfile](java/Dockerfile) 是 Java 21 / Spring Boot 的多阶段构建模板：

1. 使用 Maven 3.9.14 / Eclipse Temurin 21 Alpine 下载依赖并打包，打包命令跳过测试。
2. 通过 Spring Boot `jarmode=tools` 提取 JAR 分层。
3. 复制依赖和应用层至 `distroless/java21-debian13:debug-nonroot` 运行镜像，以 `java -jar app.jar` 启动。

JVM 启用容器支持和 G1GC，最大堆内存按容器内存的 75% 设置。基础镜像来自 Dockerfile 中配置的内部 Harbor，构建前需具备对应访问条件。

本仓库没有 Java 源码。构建上下文应指向包含 `settings.xml`、`pom.xml`、`src/` 的实际应用目录，并通过 BuildKit secret `cipw` 提供 Maven 仓库密码；`settings.xml` 需适配 `COMPANY_NEXUS_MAVEN_REPO_PASSWORD` 等环境配置。

```bash
docker build -f java/Dockerfile --secret id=cipw,src=/absolute/path/to/nexus-password -t your-java-app:local /absolute/path/to/java-project
```

模板没有声明应用端口或提供 Compose，运行参数和端口映射需由具体 Java 项目确定。

## 日常维护与排查

使用与启动时一致的 Compose 文件和项目名。例如：

```bash
# 查看中间件状态与指定服务日志
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml ps
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml logs -f mysql

# 修改 PHP 镜像配置后重新构建
docker compose --env-file php82-swool5-17/.env -p xzy -f php82-swool5-17/docker-compose.yml up -d --build

# 分别停止并移除对应模块容器
docker compose -f fastgpt/docker-compose.yaml down
docker compose -p apisix -f gateway/docker/docker-compose.yaml down
docker compose --env-file php82-swool5-17/.env -p xzy -f php82-swool5-17/docker-compose.yml down
docker compose --env-file middleware-and-database/.env -p middleware-db -f middleware-and-database/docker-compose.yml down
```

网关和 FastGPT 共用中间件网络，停中间件前应先停止这些依赖服务。`down` 不删除宿主机绑定目录内的数据。

排查时优先核对以下实际配置：

- **PHP 容器运行但无法访问**：确认已启动 Hyperf，并核对应用监听端口与 `APP_PORT`。
- **服务名无法解析**：确认容器在同一网络；PHP、Attu 默认不在共享中间件网络中。
- **MongoDB 不健康**：检查 keyfile 属主与权限、`rs0` 初始化状态及可写主节点状态。
- **FastGPT 未就绪**：查看插件、AIProxy 和代码沙箱的健康状态，确认 Redis / Milvus 凭据、MongoDB 副本集和 `aiproxy` 数据库。
- **MySQL 健康状态异常**：当前检查命令使用 `MYSQL_OPS_PASSWORD` 但未指定用户，需核对检查命令与实际账号配置。
- **APISIX 监控不可达**：当前 Prometheus 监听容器内 `127.0.0.1:9091`，仅发布端口不足以从宿主机访问；需要访问时还应调整 `plugin_attr.prometheus.export_addr.ip`。

修改配置后可用 `docker compose ... config --quiet` 检查解析结果。静态配置通过不代表镜像可拉取、容器已启动或应用初始化已完成。
