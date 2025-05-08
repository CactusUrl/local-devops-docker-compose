FROM php:8.2.27-alpine3.20

ENV WEB_ROOT=/webser/www LOG_PATH=/webser/logs DATA_PATH=/webser/data RUNTIME_PATH=/webser/runtime

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 基础镜像环境依赖
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    zlib-dev libxml2-dev freetype-dev curl-dev openssl-dev \
    linux-headers brotli-dev  pcre-dev pcre2-dev sqlite-dev \
    libzip-dev libpq-dev libjpeg-turbo-dev libjpeg-turbo freetype rabbitmq-c \
    libmcrypt libldap logrotate && \
    # 扩展依赖
    docker-php-ext-install bcmath pdo_mysql gd zip opcache pcntl sockets sysvmsg sysvsem \
    sysvshm pdo_pgsql && \
    pecl channel-update pecl.php.net && \
    # 安装二进制数据序列化扩展
    pecl install igbinary msgpack  && docker-php-ext-enable igbinary msgpack && \
    pecl install --configureoptions 'enable-redis-lzf="no" enable-redis-zstd="no"' redis-6.1.0 && \
    # PHP extension Redis swoole
    docker-php-ext-enable redis && \
    docker-php-source extract && mkdir /usr/src/php/ext/swoole && \
    curl -sfL https://github.com/swoole/swoole-src/archive/v5.1.7.tar.gz -o swoole.tar.gz && \
    tar xfz swoole.tar.gz --strip-components=1 -C /usr/src/php/ext/swoole && \
    docker-php-ext-configure swoole \
        --enable-mysqlnd       \
        --enable-brotli        \
        --enable-openssl       \
        --enable-sockets && \
    docker-php-ext-install -j$(nproc) swoole && \
    rm -f swoole.tar.gz && \
    # 安装排错工具-生产环境可不需要
    apk update && apk add --no-cache libstdc++ libpq libzip libpng nginx tcpdump busybox-extras strace && \
    apk del .build-deps $PHPIZE_DEPS && rm -rf /var/cache/apk/* && docker-php-source delete && rm -rf /etc/nginx/conf.d/* \
    #composer安装
    && php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer


# 修改 swoole.use_shortname 配置
RUN echo "swoole.use_shortname = Off" >> /usr/local/etc/php/conf.d/docker-php-ext-swoole.ini

# 设置时区
RUN apk add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    echo "date.timezone = Asia/Shanghai" >> /usr/local/etc/php/conf.d/docker-php.ini

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/php.ini /usr/local/etc/php/php.ini

WORKDIR ${WEB_ROOT}

COPY scripts/start.sh /start.sh

RUN chmod +x /start.sh

