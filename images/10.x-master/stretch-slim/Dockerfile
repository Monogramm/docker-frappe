FROM monogramm/docker-frappe-base:2.7-stretch-slim

LABEL maintainer="Monogramm Maintainers <opensource at monogramm dot io>"

# Build environment variables
ENV FRAPPE_USER=frappe \
    BENCH_BRANCH=master \
    FRAPPE_BRANCH=v10.x.x

RUN groupadd -r $FRAPPE_USER; \
    useradd -r -m -g $FRAPPE_USER $FRAPPE_USER; \
    echo 'frappe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers

USER $FRAPPE_USER
WORKDIR /home/$FRAPPE_USER

# Setup Bench
RUN set -ex; \
    test "$BENCH_BRANCH" = "4.1" && sudo pip install pip==9.0.3; \
    git clone -b $BENCH_BRANCH --depth 1 https://github.com/frappe/bench bench-repo; \
    sudo pip install -e /home/$FRAPPE_USER/bench-repo --no-cache-dir; \
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
    bench setup socketio

# Setup Frappe
RUN set -ex; \
    bench init --frappe-branch $FRAPPE_BRANCH --no-auto-update --skip-redis-config-generation frappe-bench; \
    cd frappe-bench; \
    mkdir -p apps logs sites config; \
    bench setup env; \
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

# Copy docker entrypoint and set permissions
ADD ./entrypoint.sh /entrypoint.sh
RUN sudo chmod +x /entrypoint.sh

# Runtime environment variables
ENV DOCKER_DB_TIMEOUT=120 \
    DOCKER_DB_ALLOWED_HOSTS=172.%.%.% \
    DOCKER_APPS_TIMEOUT=600 \
    DOCKER_SITES_TIMEOUT=900 \
    DOCKER_GUNICORN_PORT=8000 \
    DOCKER_GUNICORN_WORKERS=4 \
    DOCKER_GUNICORN_TIMEOUT=120 \
    FRAPPE_APP_INIT= \
    FRAPPE_DEFAULT_SITE= \
    FRAPPE_RESET_SITES= \
    FRAPPE_LOGGING=1 \
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
    MAIL_USE_SSL=tls \
    MAIL_LOGIN=frappe-mail \
    MAIL_PASSWORD=youshouldoverwritethis \
    REDIS_CACHE_HOST=redis_cache \
    REDIS_QUEUE_HOST=redis_queue \
    REDIS_SOCKETIO_HOST=redis_socketio

VOLUME /home/frappe/bench-repo \
    /home/$FRAPPE_USER/frappe-bench/logs \
    /home/$FRAPPE_USER/frappe-bench/sites

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]
