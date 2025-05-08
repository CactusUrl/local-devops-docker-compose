#!/bin/sh

mkdir -p ${WEB_ROOT} ${LOG_PATH} ${DATA_PATH} ${RUNTIME_PATH} && chown -R www-data:www-data /webser

# 目录、权限
for logdir in php hyperf nginx;
do
    if [ ! -d ${LOG_PATH}/${logdir} ]; then
        mkdir -p ${LOG_PATH}/${logdir}
        chown -R www-data. ${LOG_PATH}/${logdir}
    fi
done

# 通过 supervisor 启动服务
# exec /usr/bin/supervisord -n -c /etc/supervisord.conf
