FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        mariadb-client \
        redis-tools \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --no-cache-dir flask

COPY app/ /app/
COPY tools/init-monitor.sh /usr/local/bin/init-monitor.sh

RUN chmod +x /usr/local/bin/init-monitor.sh

EXPOSE 8083

ENTRYPOINT ["/usr/local/bin/init-monitor.sh"]
