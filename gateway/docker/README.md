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
