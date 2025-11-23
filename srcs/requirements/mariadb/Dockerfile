FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        mariadb-server \
        mariadb-client \
        gettext-base && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY conf/my.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY conf/init.sql /usr/local/etc/mariadb/init.sql
COPY tools/init-db.sh /usr/local/bin/init-db.sh

RUN chmod +x /usr/local/bin/init-db.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init-db.sh"]
