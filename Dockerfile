FROM ghcr.io/void-linux/void-glibc:latest
ARG S6_OVERLAY_VERSION=3.1.6.2
ARG WINTERCMS_VERSION=1.2.3
ENV WINTERCMS_DIR=/var/www/html
ENV USER http
ENV PHP_VERSION=8.2
ENV PHP_PATH php-fpm8.2
ENV NGINX_PATH nginx
ENV NGINX_CONF /etc/nginx/nginx.conf
ENV PHP_CONF /etc/php8.2/php.ini
ENV FPM_CONF /etc/php8.2/php-fpm.conf
ENV FPM_POOL /etc/php8.2/php-fpm.d/www.conf
ENV PATH "$PATH=/sbin:/bin:/usr/sbin:/usr/bin"

# changing mirrors
RUN mkdir -p /etc/xbps.d && \
	cp /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/ && \
	sed -i 's|https://repo-default.voidlinux.org|https://repo-fastly.voidlinux.org|g' /etc/xbps.d/*-repository-*.conf

# install nginx and php
RUN xbps-install -Syu xbps && \
	xbps-install -Syu shadow tar xz bash curl unzip openssl nginx php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-gd php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql php${PHP_VERSION}-sqlite composer${PHP_VERSION}

# add user
RUN useradd ${USER} && \
	chown -R ${USER}:${USER} /var/log && \
	mkdir /run/php && \
	chown -R ${USER}:${USER} /run/php

# config nginx
COPY conf/nginx/nginx.conf ${NGINX_CONF}

# config php
# we will not support Microsoft Drivers for PHP for SQL Server
RUN sed -i -e "s/;daemonize = yes/daemonize = no/g" ${FPM_CONF} && \
	sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${PHP_CONF} && \
	sed -i -e "s/;extension=curl/extension=curl/g" ${PHP_CONF} && \
	sed -i -e "s/;extension=gd/extension=gd/g" ${PHP_CONF} && \
	sed -i -e "s/;extension=pdo_mysql/extension=pdo_mysql/g" ${PHP_CONF} && \
	sed -i -e "s/;extension=pdo_pgsql/extension=pdo_pgsql/g" ${PHP_CONF} && \
	sed -i -e "s/;extension=pdo_sqlite/extension=pdo_sqlite/g" ${PHP_CONF} && \
	sed -i -e "s/listen = 127.0.0.1:9000/listen = \/run\/php\/php-fpm.sock/g" ${FPM_POOL}

# enable services
RUN mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d && \
	mkdir -p /etc/s6-overlay/s6-rc.d/php && \
	touch /etc/s6-overlay/s6-rc.d/php/run && \
	echo "#!/bin/sh" >> /etc/s6-overlay/s6-rc.d/php/run && \
	echo "exec s6-setuidgid ${USER} ${PHP_PATH} --fpm-config ${FPM_CONF}" >> /etc/s6-overlay/s6-rc.d/php/run && \
	chmod +x /etc/s6-overlay/s6-rc.d/php/run && \
	touch /etc/s6-overlay/s6-rc.d/php/type && \
	echo "longrun" >> /etc/s6-overlay/s6-rc.d/php/type && \
	touch /etc/s6-overlay/s6-rc.d/user/contents.d/php && \ 
	mkdir -p /etc/s6-overlay/s6-rc.d/nginx && \
	touch /etc/s6-overlay/s6-rc.d/nginx/run && \
	echo "#!/command/execlineb -P" >> /etc/s6-overlay/s6-rc.d/nginx/run && \
	echo "${NGINX_PATH}" >> /etc/s6-overlay/s6-rc.d/nginx/run && \
	chmod +x /etc/s6-overlay/s6-rc.d/nginx/run && \
	touch /etc/s6-overlay/s6-rc.d/nginx/type && \
	echo "longrun" >> /etc/s6-overlay/s6-rc.d/nginx/type && \
	touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx

# download
RUN mkdir -p /var/www && \
	curl -L -o /tmp/wintercms.zip https://github.com/wintercms/web-installer/releases/download/v${WINTERCMS_VERSION}/install.zip && \
	unzip -qq /tmp/wintercms.zip -d ${WINTERCMS_DIR} && \
	chown -R ${USER}:${USER} ${WINTERCMS_DIR}

# expose nginx
EXPOSE 80

# s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# clean xbps cache
RUN rm -rf /var/cache/xbps/* && \
	rm -rf /tmp/*

ENTRYPOINT ["/init"]
