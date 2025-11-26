FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        vsftpd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY conf/vsftpd.conf /etc/vsftpd.conf
COPY tools/init-ftp.sh /usr/local/bin/init-ftp.sh

RUN chmod +x /usr/local/bin/init-ftp.sh

EXPOSE 21 21100-21110

ENTRYPOINT ["/usr/local/bin/init-ftp.sh"]
