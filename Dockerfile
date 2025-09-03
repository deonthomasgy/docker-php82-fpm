ARG VERSION=20250830

#FROM bitnami/php-fpm:$VERSION as builder
FROM shinsenter/php-archives:$VERSION-8.4-fpm

MAINTAINER Deon Thomas "deon.thomas@invernisoft.com"

USER 0

RUN set -uex; \
    apt-get update; \
    apt-get install -y ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    NODE_MAJOR=22; \
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
