需要搭配etcd使用

etcd容器在下面的local-database-docker-compose中


**快速启动：** `docker-compose -p apisix -f docker-compose.yaml up -d`

**查看状态：** `docker ps --filter name=apisix`

**仅关闭网关apisix:** `docker-compose -f docker-compose.yaml down`


启动起来后，控制面管理后台地址：http://127.0.0.1:9000
登录账号：admin / admin
apisix的网关地址为：http://127.0.0.1:9000
