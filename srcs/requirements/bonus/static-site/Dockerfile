FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY conf/default.conf /etc/nginx/conf.d/default.conf
COPY site/ /var/www/html/

RUN chown -R www-data:www-data /var/www/html

EXPOSE 8082

CMD ["nginx", "-g", "daemon off;"]
