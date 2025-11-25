FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        php8.2 \
        php8.2-mysql \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

RUN wget -q https://www.adminer.org/latest.php -O adminer.php

COPY tools/init-adminer.sh /usr/local/bin/init-adminer.sh
RUN chmod +x /usr/local/bin/init-adminer.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/init-adminer.sh"]
