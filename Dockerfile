FROM ubuntu:18.04 AS modsecurity-build

ENV MODSECURITY_VERSION 3.0.4

RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    automake \
    autoconf \
    build-essential \
    libcurl4-openssl-dev \
    libpcre++-dev \
    libtool \
    libxml2-dev \
    libyajl-dev \
    lua5.2-dev \
    git \
    pkgconf \
    ssdeep \
    libgeoip-dev \
    wget

WORKDIR /build

RUN wget https://github.com/SpiderLabs/ModSecurity/releases/download/v${MODSECURITY_VERSION}/modsecurity-v${MODSECURITY_VERSION}.tar.gz && \
    gunzip -c modsecurity-v${MODSECURITY_VERSION}.tar.gz | tar xvf - && \
    mv modsecurity-v${MODSECURITY_VERSION} ModSecurity

WORKDIR /build/ModSecurity
RUN ./configure && \
    make && \
    make install

RUN strip /usr/local/modsecurity/bin/* /usr/local/modsecurity/lib/*.a /usr/local/modsecurity/lib/*.so*

FROM ubuntu:18.04 AS nginx-build

ENV NGINX_VERSION 1.18.0
ENV MODSECURITY_NGINX_VERSION 1.0.1

RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    autoconf \
    automake \
    build-essential \
    libtool \
    pkgconf \
    wget \
    git \
    zlib1g-dev \
    libssl-dev \
    libpcre3-dev \
    libxml2-dev \
    libyajl-dev \
    lua5.2-dev \
    libgeoip-dev \
    libcurl4-openssl-dev \
    openssl

WORKDIR /build

RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    gunzip -c nginx-${NGINX_VERSION}.tar.gz | tar xvf -

RUN wget https://github.com/SpiderLabs/ModSecurity-nginx/releases/download/v${MODSECURITY_NGINX_VERSION}/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}.tar.gz && \
    gunzip -c modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}.tar.gz | tar xvf -

COPY --from=modsecurity-build /usr/local/modsecurity/ /usr/local/modsecurity/

WORKDIR /build/nginx-${NGINX_VERSION}
RUN ./configure \
    --prefix=/usr/local/nginx \
    --sbin-path=/usr/local/nginx/nginx \
    --modules-path=/usr/local/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --user=www-data \
    --group=www-data \
    --with-pcre-jit \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_sub_module \
    --with-http_stub_status_module \
    --with-http_v2_module \
    --with-http_secure_link_module \
    --with-stream \
    --with-stream_realip_module \
    --add-module=/build/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION} \
    --with-cc-opt='-g -O2 -specs=/usr/share/dpkg/no-pie-compile.specs -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-specs=/usr/share/dpkg/no-pie-link.specs -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
    --with-http_dav_module
RUN make && \ 
    make install && \
    make modules

FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    libcurl4-openssl-dev  \
    libyajl-dev \
    lua5.2-dev \
    libgeoip-dev \
    vim \
    libxml2 \
    wget && \
    rm -r /var/lib/apt/lists/*

COPY --from=modsecurity-build /usr/local/modsecurity/ /usr/local/modsecurity/
RUN ldconfig

COPY --from=nginx-build /usr/local/nginx/nginx /usr/local/nginx/nginx

COPY --from=nginx-build /etc/nginx /etc/nginx

COPY --from=nginx-build /usr/local/nginx/html /usr/local/nginx/html

RUN mkdir -p /var/log/nginx/ && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log

RUN sed -i '38i modsecurity on;\n\tmodsecurity_rules_file /etc/nginx/modsecurity.d/include.conf;' /etc/nginx/nginx.conf && \
    mkdir -p /etc/nginx/modsecurity.d && \
    echo "include /etc/nginx/modsecurity.d/modsecurity.conf" > /etc/nginx/modsecurity.d/include.conf

COPY --from=modsecurity-build /build/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.d
COPY --from=modsecurity-build /build/ModSecurity/unicode.mapping /etc/nginx/modsecurity.d
WORKDIR /etc/nginx/modsecurity.d
RUN mv modsecurity.conf-recommended modsecurity.conf

ENV RULESET_VERSION 3.3.0

# Download ModSecurity CRS
RUN wget https://github.com/coreruleset/coreruleset/archive/v${RULESET_VERSION}.tar.gz && \
    tar -xzf v${RULESET_VERSION}.tar.gz -C /etc/nginx && \
    rm v${RULESET_VERSION}.tar.gz

# Install ModSecurity CRS
RUN cat /etc/nginx/coreruleset-${RULESET_VERSION}/crs-setup.conf.example /etc/nginx/coreruleset-${RULESET_VERSION}/rules/*.conf >> /etc/nginx/modsecurity.d/crs.conf && \
    cp /etc/nginx/coreruleset-${RULESET_VERSION}/rules/*.data /etc/nginx/modsecurity.d/ && \
    rm -rf /etc/nginx/coreruleset-* && \
    echo "include /etc/nginx/modsecurity.d/crs.conf">>/etc/nginx/modsecurity.d/include.conf

EXPOSE 80

STOPSIGNAL SIGTERM

COPY default.conf /etc/nginx/conf.d/

WORKDIR /nginx
COPY start-nginx.sh .

ENTRYPOINT ["bash", "start-nginx.sh"]