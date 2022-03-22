FROM bitnami/php-fpm:8.1-debian-10

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
        gnupg \
        build-essential \
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

RUN echo "php_value[memory_limit] = 512M" >> /opt/bitnami/php/etc/docker-php-memory-limit-512m.conf
RUN echo "php_value[date.timezone] = America/Guyana" >> /opt/bitnami/php/etc/docker-php-timezone-guyana.conf
RUN echo "php_value[upload_max_filesize] = 1024M" >> /opt/bitnami/php/etc/docker-php-max-upload-filesize-1024m.conf
RUN echo "php_value[post_max_size] = 1024M" >> /opt/bitnami/php/etc/docker-php-max-post-size-1024m.conf
#RUN echo 'max_execution_time = 1200' >> /usr/local/etc/php/conf.d/docker-php-maxexectime.ini;
#RUN sed -e 's/memory_limit = 128M/memory_limit = 512M/' -i  /usr/local/etc/php/php.ini-production
#RUN sed -e 's/memory_limit = 128M/memory_limit = 512M/' -i  /usr/local/etc/php/php.ini-development
#RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]