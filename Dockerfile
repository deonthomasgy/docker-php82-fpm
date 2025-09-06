ARG VERSION=20250830

#FROM bitnami/php-fpm:$VERSION as builder
FROM shinsenter/php-archives:$VERSION-8.4-fpm

MAINTAINER Deon Thomas "deon.thomas@invernisoft.com"

USER 0

ENV DEBUG=0 \
    TZ=America/Guyana \
    DISABLE_AUTORUN_COMPOSER_INSTALL=1 \
    DISABLE_GREETING=1 \
    DISABLE_AUTORUN_SCRIPTS=1 \
    DISABLE_AUTORUN_FIX_OWNER_GROUP=1 \
    APP_PATH=/home/thomas/WEBDEV/mintage \
    DOCUMENT_ROOT=/home/thomas/WEBDEV/mintage/public

RUN mkdir -p /usr/share/man/man1

RUN set -uex; \
    apt-get update; \
    apt-get install -y ca-certificates curl gnupg unzip mariadb-client pdftk git; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    NODE_MAJOR=22; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
     > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; 

RUN if [ -f /usr/local/etc/php/conf.d/zz-docker-shinsenter-php.ini ]; then \
        sed -i \
            -e '/memory_limit/d' \
            -e '/date.timezone/d' \
            -e '/upload_max_filesize/d' \
            -e '/post_max_size/d' \
            -e '/max_execution_time/d' \
            /usr/local/etc/php/conf.d/zz-docker-shinsenter-php.ini; \
    fi

RUN echo "memory_limit = 10240M" >> /usr/local/etc/php/conf.d/docker-php-memory-limit-10240m.ini
RUN echo "date.timezone = America/Guyana" >> /usr/local/etc/php/conf.d/docker-php-timezone-guyana.ini
RUN echo "upload_max_filesize = 256M" >> /usr/local/etc/php/conf.d/docker-php-max-upload-filesize-256m.ini
RUN echo "post_max_size = 256M" >> /usr/local/etc/php/conf.d/docker-php-max-post-size-256m.ini
RUN echo 'max_execution_time = 1800' >> /usr/local/etc/php/conf.d/docker-php-maxexectime.ini;
RUN echo 'max_input_time = 1800' >> /usr/local/etc/php/conf.d/docker-php-maxinputtime.ini;

CMD [ "php-fpm", "-F", "--pid", "/usr/local/var/run/php-fpm.pid", "-y", "/usr/local/etc/php-fpm.conf" ]
