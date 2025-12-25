FROM serversideup/php:8.5-fpm

MAINTAINER Deon Thomas "deon.thomas@invernisoft.com"

# Switch to root to install packages and extensions
USER root

# Install system dependencies
# We install Node.js 20 as requested in the original file
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gnupg \
        curl \
        ca-certificates \
        unzip \
        git \
        openssl-client \
        mariadb-client \
        pdftk \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions using the included helper script
# This handles dependencies automatically (e.g. libmagickwand for imagick)
# serversideup/php includes install-php-extensions
RUN install-php-extensions \
    imagick \
    igbinary \
    msgpack \
    redis \
    zstd \
    gd \
    intl

# Configure PHP settings
# We use environment variables supported by serversideup/php where available
ENV PHP_MEMORY_LIMIT=2048M
ENV PHP_MAX_EXECUTION_TIME=1200
ENV PHP_OPCACHE_ENABLE=1
ENV PHP_FPM_CHILD_PROCESS_USER=thomas
ENV PHP_FPM_CHILD_PROCESS_GROUP=thomas

# For settings that might not have direct ENV mapping or to ensure specific values,
# we write to a custom INI file.
RUN echo "upload_max_filesize = 128M" > /usr/local/etc/php/conf.d/custom-upload.ini \
    && echo "post_max_size = 128M" >> /usr/local/etc/php/conf.d/custom-upload.ini \
    && echo "date.timezone = America/Guyana" > /usr/local/etc/php/conf.d/custom-timezone.ini

# Create the user thomas with UID 1000 and GID 1000
RUN groupadd -g 1000 thomas \
    && useradd -u 1000 -g thomas -m -s /bin/bash thomas

# Install Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

# Set default user to root
USER www-data

# Set the default shell to bash
SHELL ["/bin/bash", "-c"]

CMD [ "php-fpm", "-F", "--pid", "/var/run/php-fpm.pid", "-y", "/usr/local/etc/php-fpm.conf" ]
