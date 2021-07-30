##
##    Docker image for Frappe applications.
##    Copyright (C) 2021 Monogramm
##
##    This program is free software: you can redistribute it and/or modify
##    it under the terms of the GNU Affero General Public License as published
##    by the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU Affero General Public License for more details.
##
##    You should have received a copy of the GNU Affero General Public License
##    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##
FROM python:3.7-slim-buster

ARG NODE_VERSION=12

ENV DEBIAN_FRONTEND="noninteractive"
ARG WKHTMLTOX_VERSION=0.12.4
ARG DOCKERIZE_VERSION=v0.6.1

# Frappe base environment
RUN set -ex; \
    apt-get update; \
    apt-get install -y software-properties-common gnupg2 curl; \
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8; \
    add-apt-repository "deb http://ams2.mirrors.digitalocean.com/mariadb/repo/10.5/debian buster main"; \
    curl -sL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -; \
    curl -sS "https://dl.yarnpkg.com/debian/pubkey.gpg" | apt-key add -; \
    apt-get update; \
    apt-get install -y --allow-unauthenticated \
        sudo \
        wget \
        nodejs \
        python-mysqldb \
        git \
        build-essential \
        python-setuptools \
        python-dev \
        libffi-dev \
        libssl-dev  \
        ntp \
        screen \
        mariadb-client \
        mariadb-common \
        postgresql-client \
        postgresql-client-common \
        libxslt1.1 \
        libxslt1-dev \
        libcrypto++-dev \
        python-openssl \
        python-ldap3 \
        python-psycopg2 \
        libtiff5-dev \
        libjpeg62-turbo-dev \
        liblcms2-dev \
        libwebp-dev \
        tcl8.6-dev \
        tk8.6-dev \
        python-tk \
        zlib1g-dev \
        libfreetype6-dev \
        fontconfig \
        libxrender1 \
        libxext6 \
        xfonts-75dpi \
        xfonts-base \
    ; \
    test "${NODE_VERSION}" = "8" && apt-get install -y --allow-unauthenticated npm; \
    mkdir /tmp/.X11-unix; \
    chmod 777 /tmp/.X11-unix; \
    chown root:root /tmp/.X11-unix; \
    node --version; \
    npm --version; \
    npm install -g yarn; \
    yarn --version; \
    rm -rf /var/lib/apt/lists/*; \
    wget "https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox-${WKHTMLTOX_VERSION}_linux-generic-amd64.tar.xz"; \
    tar xf "wkhtmltox-${WKHTMLTOX_VERSION}_linux-generic-amd64.tar.xz"; \
    mv wkhtmltox/bin/* /usr/local/bin/; \
    rm "wkhtmltox-${WKHTMLTOX_VERSION}_linux-generic-amd64.tar.xz"; \
    wkhtmltopdf --version; \
    wget "https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz"; \
    tar -C /usr/local/bin -xzvf "dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz"; \
    rm "dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz"; \
    pip install --upgrade setuptools pip pip-tools; \
    pip --version

ARG VERSION=v12.20.0
ARG FRAPPE_USER=frappe
ARG FRAPPE_UID=1000
ARG FRAPPE_GID=1000
ARG FRAPPE_PATH=https://github.com/frappe/frappe.git

# Build environment variables
ENV FRAPPE_USER=${FRAPPE_USER} \
    BENCH_BRANCH=master \
    FRAPPE_BRANCH=${VERSION}

RUN set -ex; \
    groupadd -r "${FRAPPE_USER}" -g "${FRAPPE_GID}"; \
    useradd -r -m -g "${FRAPPE_USER}" -u "${FRAPPE_UID}" "${FRAPPE_USER}"; \
    echo 'frappe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers

USER $FRAPPE_USER
WORKDIR /home/$FRAPPE_USER

# Setup Bench and Frappe
RUN set -ex; \
    test "$BENCH_BRANCH" = "4.1" && sudo pip install pip==9.0.3; \
    git clone -b "$BENCH_BRANCH" --depth 1 'https://github.com/frappe/bench' bench-repo; \
    sudo pip3 install -e "/home/$FRAPPE_USER/bench-repo" --no-cache-dir; \
    bench --version; \
    npm install \
        chalk \
        rollup \
        rollup-plugin-multi-entry \
        rollup-plugin-commonjs \
        rollup-plugin-node-resolve \
        rollup-plugin-uglify \
        rollup-plugin-postcss \
        rollup-plugin-buble \
        rollup-plugin-terser \
        rollup-plugin-vue \
        vue-template-compiler \
        moment \
    ; \
    test "$BENCH_BRANCH" = "4.1" && npm install \
        babel-core \
        babel-plugin-transform-object-rest-spread \
        babel-preset-env \
        touch \
    ; \
    bench setup socketio; \
    bench init \
        --frappe-path "$FRAPPE_PATH" \
        --frappe-branch "$FRAPPE_BRANCH" \
        --python $(which python3.7) \
        --skip-redis-config-generation --no-backups frappe-bench \
    ; \
    bench --version; \
    rm -rf node_modules; \
    cd frappe-bench; \
    mkdir -p apps logs sites config; \
    sed -i -e "s|^werkzeug$|werkzeug==0.16.1|g" apps/frappe/requirements.txt; \
    grep 'ldap3==2.7' apps/frappe/requirements.txt || echo 'ldap3==2.7' >> apps/frappe/requirements.txt; \
    test ! "$FRAPPE_BRANCH" = "v10.x.x" && bench setup env --python $(which python3.7) ; \
    sudo bench setup sudoers "$FRAPPE_USER"

# Alternative: replace previous run by this for manual install
#RUN set -ex; \
#    mkdir -p frappe-bench; \
#    cd frappe-bench; \
#    mkdir -p apps logs sites config; \
#    bench setup env; \
#    sudo bench setup sudoers "$FRAPPE_USER"; \
#    bench get-app frappe 'https://github.com/frappe/frappe' --branch "$FRAPPE_BRANCH"; \
#    cd "/home/$FRAPPE_USER/frappe-bench/apps/frappe"; \
#    npm install; \
#    cd "/home/$FRAPPE_USER/frappe-bench"; \
#    npm install babel-preset-env; \
#    rm -rf "/home/$FRAPPE_USER/bench-repo/.git"; \
#    rm -rf "/home/$FRAPPE_USER/frappe-bench/apps/frappe/.git"

# Runtime environment variables
ENV DOCKER_DB_TIMEOUT=240 \
    DOCKER_DB_ALLOWED_HOSTS= \
    DOCKER_SITES_TIMEOUT=600 \
    DOCKER_APPS_TIMEOUT=720 \
    DOCKER_INIT_TIMEOUT=300 \
    DOCKER_DEBUG= \
    DOCKER_GUNICORN_BIND_ADDRESS=0.0.0.0 \
    DOCKER_GUNICORN_PORT=8000 \
    DOCKER_GUNICORN_WORKERS=4 \
    DOCKER_GUNICORN_TIMEOUT=240 \
    DOCKER_GUNICORN_LOGLEVEL=info \
    FRAPPE_APP_INIT= \
    FRAPPE_APP_RESET= \
    FRAPPE_APP_PROTECTED=frappe \
    FRAPPE_DEFAULT_PROTOCOL=http \
    FRAPPE_DEFAULT_SITE= \
    FRAPPE_HTTP_PORT=80 \
    FRAPPE_WEBSERVER_PORT=80 \
    FRAPPE_SOCKETIO_PORT=3000 \
    FRAPPE_RESET_SITES= \
    FRAPPE_REINSTALL_DATABASE= \
    FRAPPE_BUILD_OPTIONS= \
    FRAPPE_LOGGING=1 \
    GOOGLE_ANALYTICS_ID= \
    SERVER_SCRIPT_ENABLED=0 \
    ALLOW_TESTS=0 \
    DEVELOPER_MODE=0 \
    ADMIN_PASSWORD=frappe \
    ENCRYPTION_KEY= \
    DB_TYPE=mariadb \
    DB_HOST=db \
    DB_PORT=3306 \
    DB_NAME=frappe \
    DB_PASSWORD=youshouldoverwritethis \
    DB_ROOT_LOGIN=root \
    DB_ROOT_PASSWORD=mariadb_root_password \
    MAIL_MUTED=false \
    MAIL_HOST=mail \
    MAIL_PORT=587 \
    MAIL_USE_SSL=1 \
    MAIL_USE_TLS=1 \
    MAIL_LOGIN=frappe-mail \
    MAIL_PASSWORD=youshouldoverwritethis \
    MAIL_EMAIL_ID= \
    MAIL_SENDER_NAME=Notifications \
    MAIL_ALWAYS_EMAIL_ID_AS_SENDER=0 \
    MAIL_ALWAYS_NAME_AS_SENDER_NAME=0 \
    REDIS_CACHE_HOST=redis_cache \
    REDIS_QUEUE_HOST=redis_queue \
    REDIS_SOCKETIO_HOST=redis_socketio

# Copy docker entrypoint
COPY ./entrypoint.sh /

# Set permissions
RUN set -ex; \
    sudo mkdir -p "/home/$FRAPPE_USER"/frappe-bench/logs; \
    sudo touch "/home/$FRAPPE_USER"/frappe-bench/logs/bench.log; \
    sudo chmod +rw \
        "/home/$FRAPPE_USER"/frappe-bench/logs \
        "/home/$FRAPPE_USER"/frappe-bench/logs/* \
    ; \
    sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
        "/home/$FRAPPE_USER/frappe-bench" \
    ;

#VOLUME /home/$FRAPPE_USER/bench-repo \
#    /home/$FRAPPE_USER/frappe-bench/logs \
#    /home/$FRAPPE_USER/frappe-bench/sites \
#    /home/$FRAPPE_USER/frappe-bench/apps/frappe/frappe/public

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]

ARG TAG
ARG VCS_REF
ARG BUILD_DATE

# Docker built environment variables
ENV DOCKER_TAG=${TAG} \
    DOCKER_VCS_REF=${VCS_REF} \
    DOCKER_BUILD_DATE=${BUILD_DATE}

LABEL maintainer="Monogramm Maintainers <opensource at monogramm dot io>" \
      product="Frappe" \
      version=$VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Monogramm/docker-frappe" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Frappe" \
      org.label-schema.description="Python + JS based metadata driven, full-stack web-application framework." \
      org.label-schema.url="https://frappe.io/" \
      org.label-schema.vendor="Frappé Technologies Pvt. Ltd" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"
