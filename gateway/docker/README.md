需要搭配etcd使用

etcd容器在下面的local-database-docker-compose中


**快速启动：** `docker compose -p apisix -f docker-compose.yaml up -d --remove-orphans`

**查看状态：** `docker ps --filter name=apisix`

**仅关闭网关 APISIX：** `docker compose -p apisix -f docker-compose.yaml down --remove-orphans`


启动后，APISIX 3.17 内置管理后台地址：http://127.0.0.1:9000/ui/

首次打开后台时，填写 `config.yaml` 中 `deployment.admin.admin_key` 配置的 Admin API Key。

新版 Dashboard 没有独立的 `/plugin/list` 页面。请在 Routes、Services、Consumers 或 Global Rules 的编辑页面中配置对应插件。

APISIX 网关地址：http://127.0.0.1:9080

> 不再使用独立的 `apache/apisix-dashboard` 镜像。旧 Dashboard 3.0.1 仅兼容 APISIX 3.0，和 APISIX 3.17 混用会导致插件等页面异常。

## UMC 权限校验

路由使用 `umc-auth` 插件调用 UMC。插件不会向 UMC 转发客户端的 `Authorization` 请求头，
但会转发 `Cookie`，供 UMC 读取 `umc_auth_session_id` 会话，
并会自动传递以下查询参数：

- `router`：去掉第一段网关前缀后的请求路径，不包含查询参数。
- `method`：小写的原始请求方法。
- `gateway_prefix`：原始请求路径的第一段。

例如 `/erp-core-business/cli/platform/shopee/media_space.upload_image` 会请求：

```text
https://api.test.szad.teehmoon.com/umc/user/auth?router=%2Fcli%2Fplatform%2Fshopee%2Fmedia_space.upload_image&method=get&gateway_prefix=erp-core-business
```

Dashboard 的插件配置填写内部配置即可：

```json
{
  "uri": "https://api.test.szad.teehmoon.com/umc/user/auth",
  "gateway_prefix": "erp-core-business",
  "ssl_verify": true,
  "timeout": 3000,
  "status_on_error": 503,
  "allow_degradation": false
}
```

特殊请求处理：

- 最后一段为 `health` 的请求（如 `/oms/health`、`/oms/platform/health`）跳过 UMC 鉴权，继续转发到下游。
- 一段网关前缀（如 `/oms`、`/oms/`）或以 `/` 结尾的两段前缀（如 `/oms/platform/`），由 APISIX 直接返回纯文本 `hello world`，不会请求 UMC 或下游服务。
