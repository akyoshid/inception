FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        nginx \
        openssl \
        gettext-base && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl
ARG DOMAIN_NAME
# openssl req:
#   Command to generate certificate signing requests or self-signed certificates
# -x509: Create a self-signed certificate (X.509)
#   A certificate contains the public key
#    & certificate information (Subject DN, signature, validity period, etc.)
# -nodes: Do not protect the private key with a password
# -days: Validity period
# -newkey: Generate a new private key
# -keyout: Destination for the private key output
# -out: Destination for the certificate output
# -subj:
#   Skip interactive prompts
#    & allow specifying the certificate's subject information (Subject DN)
#    directly on the command line
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=JP/ST=Tokyo/L=Shinjuku-ku/O=42Tokyo/CN=${DOMAIN_NAME}"

COPY conf/default.conf /etc/nginx/conf.d/default.conf.template
COPY tools/init-nginx.sh /usr/local/bin/init-nginx.sh
RUN chmod +x /usr/local/bin/init-nginx.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/init-nginx.sh"]
