ARG VERSION=8.4.11-debian-12-r5

#FROM bitnami/php-fpm:$VERSION as builder
FROM serversideup/php:8.4-fpm as builder

MAINTAINER Deon Thomas "deon.thomas@invernisoft.com"
USER 0
# Install modules -
RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libwebp-dev \
        libpng-dev \
        libonig-dev \
        libmagickwand-dev \
        libzip-dev \
        libzstd-dev \
        libpq-dev \
        gnupg \
        build-essential \
    && ln -s /usr/lib/x86_64-linux-gnu/ImageMagick-6.9.11/bin-q16/MagickWand-config /usr/bin \
    && rm -rf /var/lib/apt/lists/*

# Install igbinary (for more efficient serialization in redis/memcached)
RUN for i in $(seq 1 3); do pecl install -o imagick && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini

# Install igbinary (for more efficient serialization in redis/memcached)
RUN for i in $(seq 1 3); do pecl install -o igbinary && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && echo "extension=igbinary.so" > /usr/local/etc/php/conf.d/igbinary.ini

# Install xhprof
RUN for i in $(seq 1 3); do pecl install xhprof && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && echo "extension=xhprof.so" > /usr/local/etc/php/conf.d/xhprof.ini

# Install redis (manualy build in order to be able to enable igbinary)
RUN for i in $(seq 1 3); do pecl install -o --nobuild redis && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/redis" \
    && phpize \
    && ./configure --enable-redis-igbinary --enable-redis-lzf  \
    && make \
    && make install \
    && cd - \
    && echo "extension=redis.so" > /usr/local/etc/php/conf.d/redis.ini

# Install pcov
RUN for i in $(seq 1 3); do pecl install -o --nobuild pcov && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/pcov" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=pcov.so" > /usr/local/etc/php/conf.d/pcov.ini

# Install excimer
RUN for i in $(seq 1 3); do pecl install -o --nobuild excimer && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/excimer" \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && cd - \
    && echo "extension=excimer.so" > /usr/local/etc/php/conf.d/excimer.ini

FROM serversideup/php:8.4-fpm

COPY --from=builder /usr/local/etc/php/conf.d/ext-imagick.ini /usr/local/etc/php/conf.d/ext-imagick.ini
COPY --from=builder /usr/local/lib/php/extensions/imagick.so /usr/local/lib/php/extensions/imagick.so

COPY --from=builder /usr/local/etc/php/conf.d/igbinary.ini /usr/local/etc/php/conf.d/igbinary.ini
COPY --from=builder /usr/local/lib/php/extensions/igbinary.so /usr/local/lib/php/extensions/igbinary.so

COPY --from=builder /usr/local/etc/php/conf.d/redis.ini /usr/local/etc/php/conf.d/redis.ini
COPY --from=builder /usr/local/lib/php/extensions/redis.so /usr/local/lib/php/extensions/redis.so

COPY --from=builder /usr/local/etc/php/conf.d/pcov.ini /usr/local/etc/php/conf.d/pcov.ini
COPY --from=builder /usr/local/lib/php/extensions/pcov.so /usr/local/lib/php/extensions/pcov.so

COPY --from=builder /usr/local/etc/php/conf.d/excimer.ini /usr/local/etc/php/conf.d/excimer.ini
COPY --from=builder /usr/local/lib/php/extensions/excimer.so /usr/local/lib/php/extensions/excimer.so

COPY --from=builder /usr/local/etc/php/conf.d/xhprof.ini /usr/local/etc/php/conf.d/xhprof.ini
COPY --from=builder /usr/local/lib/php/extensions/xhprof.so /usr/local/lib/php/extensions/xhprof.so


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

RUN apt-get update && apt-get install -y --no-install-recommends nodejs unzip mariadb-client pdftk git && rm -rf /var/lib/apt/lists/*

RUN echo "memory_limit = 2048M" >> /usr/local/etc/php/conf.d/docker-php-memory-limit-1024m.ini
RUN echo "date.timezone = America/Guyana" >> /usr/local/etc/php/conf.d/docker-php-timezone-guyana.ini
RUN echo "upload_max_filesize = 128M" >> /usr/local/etc/php/conf.d/docker-php-max-upload-filesize-128m.ini
RUN echo "post_max_size = 128M" >> /usr/local/etc/php/conf.d/docker-php-max-post-size-128m.ini
RUN echo 'max_execution_time = 1200' >> /usr/local/etc/php/conf.d/docker-php-maxexectime.ini;

CMD [ "php-fpm", "-F", "--pid", "/usr/local/var/run/php-fpm.pid", "-y", "/usr/local/etc/php-fpm.conf" ]
