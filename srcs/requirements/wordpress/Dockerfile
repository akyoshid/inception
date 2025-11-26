FROM debian:bookworm

# Install required packages including WP-CLI
RUN apt-get update && \
    apt-get install -y \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        php8.2-redis \
        wget \
        mariadb-client \
        redis-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    wget -q \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/init-wp.sh /usr/local/bin/init-wp.sh

RUN chmod +x /usr/local/bin/init-wp.sh && \
    # Directory for placing php-fpm sockets
    mkdir -p /run/php && \
    chown -R www-data:www-data /run/php

# Create this directory if it does not exist
# Subsequent RUN, CMD, ENTRYPOINT, etc. will be executed in this directory
WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/init-wp.sh"]
