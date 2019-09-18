##
##    Docker image for Frappe applications.
##    Copyright (C) 2019  Monogramm
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
FROM monogramm/docker-frappe-base:alpine

ARG TAG
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION=develop

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

# Build environment variables
ENV DOCKER_TAG=${TAG} \
    DOCKER_VCS_REF=${VCS_REF} \
    DOCKER_BUILD_DATE=${BUILD_DATE} \
    FRAPPE_USER=frappe \
    BENCH_BRANCH=master \
    FRAPPE_BRANCH=${VERSION}

RUN set -ex; \
    addgroup -S $FRAPPE_USER; \
    adduser -D -G $FRAPPE_USER $FRAPPE_USER; \
    echo 'frappe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers

USER $FRAPPE_USER
WORKDIR /home/$FRAPPE_USER

# Setup Bench and Frappe
RUN set -ex; \
    test "$BENCH_BRANCH" = "4.1" && sudo pip install pip==9.0.3; \
    git clone -b $BENCH_BRANCH --depth 1 https://github.com/frappe/bench bench-repo; \
    sudo pip3 install -e /home/$FRAPPE_USER/bench-repo --no-cache-dir; \
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
        --frappe-branch $FRAPPE_BRANCH \
        --no-auto-update \
        --python $(which python3) \
        --skip-redis-config-generation frappe-bench \
    ; \
    rm -rf node_modules; \
    cd frappe-bench; \
    mkdir -p apps logs sites config; \
    test ! "$FRAPPE_BRANCH" = "v10.x.x" && bench setup env --python $(which python3) ; \
    sudo bench setup sudoers $FRAPPE_USER

# Alternative: replace previous run by this for manual install
#RUN set -ex; \
#    mkdir -p frappe-bench; \
#    cd frappe-bench; \
#    mkdir -p apps logs sites config; \
#    bench setup env; \
#    sudo bench setup sudoers $FRAPPE_USER; \
#    bench get-app frappe https://github.com/frappe/frappe --branch $FRAPPE_BRANCH; \
#    cd /home/$FRAPPE_USER/frappe-bench/apps/frappe; \
#    npm install; \
#    cd /home/$FRAPPE_USER/frappe-bench; \
#    npm install babel-preset-env; \
#    rm -rf /home/$FRAPPE_USER/bench-repo/.git; \
#    rm -rf /home/$FRAPPE_USER/frappe-bench/apps/frappe/.git

# Copy docker entrypoint and private install script
ADD ./entrypoint.sh /

# Set permissions
RUN set -ex; \
    sudo chmod +x \
        /entrypoint.sh \
    ; \
    sudo mkdir -p "/home/$FRAPPE_USER"/frappe-bench/logs; \
    sudo touch "/home/$FRAPPE_USER"/frappe-bench/logs/bench.log; \
    sudo chmod +rw \
        "/home/$FRAPPE_USER"/frappe-bench/logs \
        "/home/$FRAPPE_USER"/frappe-bench/logs/* \
    ; \
    sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
        "/home/$FRAPPE_USER/frappe-bench" \
    ;

VOLUME /home/$FRAPPE_USER/bench-repo \
    /home/$FRAPPE_USER/frappe-bench/logs \
    /home/$FRAPPE_USER/frappe-bench/sites \
    /home/$FRAPPE_USER/frappe-bench/apps/frappe/frappe/public

# Runtime environment variables
ENV DOCKER_DB_TIMEOUT=120 \
    DOCKER_DB_ALLOWED_HOSTS= \
    DOCKER_SITES_TIMEOUT=600 \
    DOCKER_APPS_TIMEOUT=720 \
    DOCKER_INIT_TIMEOUT=300 \
    DOCKER_DEBUG= \
    DOCKER_GUNICORN_BIND_ADDRESS=0.0.0.0 \
    DOCKER_GUNICORN_PORT=8000 \
    DOCKER_GUNICORN_WORKERS=4 \
    DOCKER_GUNICORN_TIMEOUT=120 \
    DOCKER_GUNICORN_LOGLEVEL=info \
    FRAPPE_APP_INIT= \
    FRAPPE_APP_RESET= \
    FRAPPE_APP_PROTECTED=frappe \
    FRAPPE_DEFAULT_PROTOCOL= \
    FRAPPE_DEFAULT_SITE= \
    FRAPPE_RESET_SITES= \
    FRAPPE_REINSTALL_DATABASE= \
    FRAPPE_BUILD_OPTIONS= \
    FRAPPE_LOGGING=1 \
    GOOGLE_ANALYTICS_ID= \
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
    MAIL_LOGIN=frappe-mail \
    MAIL_PASSWORD=youshouldoverwritethis \
    MAIL_EMAIL_ID= \
    MAIL_SENDER_NAME=Notifications \
    MAIL_ALWAYS_EMAIL_ID_AS_SENDER=0 \
    MAIL_ALWAYS_NAME_AS_SENDER_NAME=0 \
    REDIS_CACHE_HOST=redis_cache \
    REDIS_QUEUE_HOST=redis_queue \
    REDIS_SOCKETIO_HOST=redis_socketio

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]
