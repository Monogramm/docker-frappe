FROM monogramm/docker-frappe-base:2.7-alpine

LABEL maintainer="Monogramm Maintainers <opensource at monogramm dot io>"

# Build environments
ENV FRAPPE_USER=frappe \
	BENCH_BRANCH=4.1 \
	FRAPPE_BRANCH=v10.1.67

RUN addgroup -S $FRAPPE_USER; \
    adduser -D -G $FRAPPE_USER $FRAPPE_USER; \
    echo 'frappe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers

USER $FRAPPE_USER
WORKDIR /home/$FRAPPE_USER

# Setup Frappe folders
RUN set -ex; \
    git clone -b $BENCH_BRANCH --depth 1 https://github.com/frappe/bench bench-repo; \
    test "$BENCH_BRANCH" = "4.1" && sudo pip install pip==9.0.3; \
    sudo pip install -e /home/$FRAPPE_USER/bench-repo --no-cache-dir; \
    sudo npm install -g yarn; \
    npm install \
        chalk \
        rollup \
        rollup-plugin-multi-entry \
        rollup-plugin-commonjs \
        rollup-plugin-node-resolve \
        rollup-plugin-uglify \
        rollup-plugin-postcss \
    ; \
    bench setup socketio; \
    bench init --ignore-exist --skip-redis-config-generation frappe-bench; \
    cd frappe-bench; \
    mkdir -p apps logs sites/localhost config; \
    bench setup env; \
    sudo bench setup sudoers $FRAPPE_USER; \
    bench get-app frappe https://github.com/frappe/frappe --branch $FRAPPE_BRANCH

# Copy docker entrypoint and set permissions
ADD ./entrypoint.sh /entrypoint.sh
RUN sudo chmod +x /entrypoint.sh

VOLUME /home/$FRAPPE_USER/frappe-bench/logs

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]
