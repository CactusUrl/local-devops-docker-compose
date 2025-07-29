> 请在.env文件中配置密码,DATA_PATH=数据存储映射目录

#### 构建命令
- 对应up命令
  `docker-compose -p xzy up -d`
  - 更改Dockerfile后重新构建
  `docker-compose -p xzy up --build`
- 对应remove命令
  `docker-compose down`
