FROM serversideup/php:8.4.26-fpm

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
        openssh-client \
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
# PECL REST info.xml is currently 404, so PECL-only extensions are installed
# from GitHub tags. redis is already provided by the base image.
RUN install-php-extensions \
    Imagick/imagick@3.8.1 \
    igbinary/igbinary@3.2.16 \
    msgpack/msgpack-php@v3.0.1 \
    zstd \
    gd \
    intl \
    exif \
    bcmath

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

# Configure PHP-FPM pool settings
# Modify the existing pool configuration to set user/group (preserves listen = 9000 and other defaults)
# The base image provides a full config with listen = 9000 and ping.response, we just need to uncomment and set user/group
RUN sed -i 's/^;user = www-data/user = thomas/' /usr/local/etc/php-fpm.d/docker-php-serversideup-pool.conf \
    && sed -i 's/^;group = www-data/group = thomas/' /usr/local/etc/php-fpm.d/docker-php-serversideup-pool.conf

# Install Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

# Set default user to root
USER root

# Set the default shell to bash
SHELL ["/bin/bash", "-c"]

# Copy entrypoint script and make it executable
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set entrypoint (CMD becomes arguments to entrypoint)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD [ "php-fpm", "-F", "--pid", "/var/run/php-fpm.pid", "-y", "/usr/local/etc/php-fpm.conf" ]
