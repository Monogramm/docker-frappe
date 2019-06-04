FROM monogramm/docker-frappe-base:stretch-slim

LABEL maintainer="Monogramm Maintainers <opensource at monogramm dot io>"

# Build environment variables
ENV FRAPPE_USER=frappe \
	BENCH_BRANCH=master \
	FRAPPE_BRANCH=v11.1.32

RUN groupadd -r $FRAPPE_USER; \
    useradd -r -m -g $FRAPPE_USER $FRAPPE_USER; \
    echo 'frappe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers

USER $FRAPPE_USER
WORKDIR /home/$FRAPPE_USER

# Setup Frappe folders
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
    bench setup socketio; \
    bench init --skip-redis-config-generation frappe-bench; \
    cd frappe-bench; \
    mkdir -p apps logs sites/localhost config; \
    bench setup env; \
    sudo bench setup sudoers $FRAPPE_USER

# Copy docker entrypoint and set permissions
ADD ./entrypoint.sh /entrypoint.sh
RUN sudo chmod +x /entrypoint.sh

# Runtime environment variables
ENV FRAPPE_DOCKER_INIT=0 \
	ADMIN_PASSWORD=frappe \
	DB_HOST=db \
	DB_PORT=3306 \
	DB_NAME=frappe \
	DB_USER=frappe \
	DB_PASSWORD=youshouldoverwritethis \
	ROOT_PASSWORD=mariadb_root_password \
	ENCRYPTION_KEY=youshoulddefinitelyoverwritethis \
	REDIS_CACHE_HOST=redis_cache \
	REDIS_QUEUE_HOST=redis_queue \
	REDIS_SOCKETIO_HOST=redis_socketio \
	MAIL_HOST=mail \
	MAIL_PORT=587 \
	MAIL_USE_SSL=tls \
	MAIL_LOGIN=frappe-mail \
	MAIL_PASSWORD=youshouldoverwritethis

VOLUME /home/$FRAPPE_USER/frappe-bench/logs

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]
