> 请在.env文件中配置密码,DATA_PATH=数据存储映射目录
### 容器镜像group包含
##### redis
- 密码在.env中配置项：
##### mysql8.0
- 密码在.env中配置项：
##### rabbitmq3.13
- 版本要求大于3.5且小于4.0
- 密码在.env中配置项：RABBIT_MQ_PASSWORD

#### 构建命令
- 对应up命令
  `docker-compose -p middleware-db up -d`
- 对应remove命令
  `docker-compose down -p middleware-db`
