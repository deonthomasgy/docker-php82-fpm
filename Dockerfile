ARG VERSION=8.3.14-debian-12-r0

FROM bitnami/php-fpm:$VERSION as builder

MAINTAINER Deon Thomas "deon.thomas@invernisoft.com"

# Install modules -
RUN install_packages \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libwebp-dev \
        libpng-dev \
        libmagickwand-6.q16-dev \
        libonig-dev \
        libzip-dev \
        libzstd-dev \
        libpq-dev \
        gnupg \
        build-essential \
    && ln -s /usr/lib/x86_64-linux-gnu/ImageMagick-6.9.11/bin-q16/MagickWand-config /usr/bin 

# Install igbinary (for more efficient serialization in redis/memcached)
RUN for i in $(seq 1 3); do pecl install -o imagick && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && echo "extension=imagick.so" > /opt/bitnami/php/etc/conf.d/ext-imagick.ini

# Install igbinary (for more efficient serialization in redis/memcached)
RUN for i in $(seq 1 3); do pecl install -o igbinary && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && echo "extension=igbinary.so" > /opt/bitnami/php/etc/conf.d/igbinary.ini

# Install xhprof
RUN for i in $(seq 1 3); do pecl install -o --nobuild xhprof && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/xhprof" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=xhprof.so" > /opt/bitnami/php/etc/conf.d/xhprof.ini

# Install msgpack
RUN for i in $(seq 1 3); do pecl install -o --nobuild msgpack && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/msgpack" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=msgpack.so" > /opt/bitnami/php/etc/conf.d/msgpack.ini

# Install redis (manualy build in order to be able to enable igbinary)
RUN for i in $(seq 1 3); do pecl install -o --nobuild redis && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/redis" \
    && phpize \
    && ./configure --enable-redis-igbinary --enable-redis-lzf --enable-redis-msgpack --enable-redis-zstd \
    && make \
    && make install \
    && cd - \
    && echo "extension=redis.so" > /opt/bitnami/php/etc/conf.d/redis.ini

# Install pcov
RUN for i in $(seq 1 3); do pecl install -o --nobuild pcov && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/pcov" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=pcov.so" > /opt/bitnami/php/etc/conf.d/pcov.ini

# Install zstd
RUN for i in $(seq 1 3); do pecl install -o --nobuild zstd && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/zstd" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=zstd.so" > /opt/bitnami/php/etc/conf.d/zstd.ini

# Install excimer
RUN for i in $(seq 1 3); do pecl install -o --nobuild excimer && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/excimer" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=excimer.so" > /opt/bitnami/php/etc/conf.d/excimer.ini

FROM bitnami/php-fpm:$VERSION

COPY --from=builder /opt/bitnami/php/etc/conf.d/ext-imagick.ini /opt/bitnami/php/etc/conf.d/ext-imagick.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/imagick.so /opt/bitnami/php/lib/php/extensions/imagick.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/igbinary.ini /opt/bitnami/php/etc/conf.d/igbinary.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/igbinary.so /opt/bitnami/php/lib/php/extensions/igbinary.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/redis.ini /opt/bitnami/php/etc/conf.d/redis.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/redis.so /opt/bitnami/php/lib/php/extensions/redis.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/pcov.ini /opt/bitnami/php/etc/conf.d/pcov.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/pcov.so /opt/bitnami/php/lib/php/extensions/pcov.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/zstd.ini /opt/bitnami/php/etc/conf.d/zstd.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/zstd.so /opt/bitnami/php/lib/php/extensions/zstd.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/excimer.ini /opt/bitnami/php/etc/conf.d/excimer.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/excimer.so /opt/bitnami/php/lib/php/extensions/excimer.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/xhprof.ini /opt/bitnami/php/etc/conf.d/xhprof.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/xhprof.so /opt/bitnami/php/lib/php/extensions/xhprof.so

COPY --from=builder /opt/bitnami/php/etc/conf.d/msgpack.ini /opt/bitnami/php/etc/conf.d/msgpack.ini
COPY --from=builder /opt/bitnami/php/lib/php/extensions/msgpack.so /opt/bitnami/php/lib/php/extensions/msgpack.so


# Install Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

RUN set -uex; \
    apt-get update; \
    apt-get install -y ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    NODE_MAJOR=20; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
     > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; 

RUN install_packages nodejs unzip mariadb-client pdftk git 

RUN echo "memory_limit = 2048M" >> /opt/bitnami/php/etc/conf.d/docker-php-memory-limit-1024m.ini
RUN echo "date.timezone = America/Guyana" >> /opt/bitnami/php/etc/conf.d/docker-php-timezone-guyana.ini
RUN echo "upload_max_filesize = 128M" >> /opt/bitnami/php/etc/conf.d/docker-php-max-upload-filesize-128m.ini
RUN echo "post_max_size = 128M" >> /opt/bitnami/php/etc/conf.d/docker-php-max-post-size-128m.ini
RUN echo 'max_execution_time = 1200' >> /opt/bitnami/php/etc/conf.d/docker-php-maxexectime.ini;

CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]
