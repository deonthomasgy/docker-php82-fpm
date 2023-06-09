FROM bitnami/php-fpm:8.2.6-debian-11-r9

MAINTAINER Deon Thomas "Deon.Thomas.GY@gmail.com"

# Install modules -
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libwebp-dev \
        libpng-dev \
        libmagickwand-6.q16-dev \
        libonig-dev \
        libzip-dev \
        unzip \
        gnupg \
        build-essential \
        pdftk \
    && ln -s /usr/lib/x86_64-linux-gnu/ImageMagick-6.9.10/bin-q16/MagickWand-config /usr/bin \
    && pecl install imagick \
    && echo "extension=imagick.so" > /opt/bitnami/php/etc/conf.d/ext-imagick.ini

# Install igbinary (for more efficient serialization in redis/memcached)
RUN for i in $(seq 1 3); do pecl install -o igbinary && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && echo "extension=igbinary.so" > /opt/bitnami/php/etc/conf.d/igbinary.ini

# Install redis (manualy build in order to be able to enable igbinary)
RUN for i in $(seq 1 3); do pecl install -o --nobuild redis && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/redis" \
    && phpize \
    && ./configure --enable-redis-igbinary \
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


# Install Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

# Install MySQL Client
RUN apt-get install git mariadb-client -y

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install nodejs -y

RUN apt-get remove -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libwebp-dev \
        libpng-dev \
        libmagickwand-6.q16-dev \
        libonig-dev \
        libzip-dev \
        gnupg \
        build-essential

RUN apt-get auto-remove -y

RUN echo "memory_limit = 1024M" >> /opt/bitnami/php/etc/conf.d/docker-php-memory-limit-1024m.ini
RUN echo "date.timezone = America/Guyana" >> /opt/bitnami/php/etc/conf.d/docker-php-timezone-guyana.ini
RUN echo "upload_max_filesize = 128M" >> /opt/bitnami/php/etc/conf.d/docker-php-max-upload-filesize-1024m.ini
RUN echo "post_max_size = 128M" >> /opt/bitnami/php/etc/conf.d/docker-php-max-post-size-1024m.ini
RUN echo 'max_execution_time = 1200' >> /opt/bitnami/php/etc/conf.d/docker-php-maxexectime.ini;

CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]
