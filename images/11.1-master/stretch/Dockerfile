FROM monogramm/docker-frappe-base:stretch

LABEL maintainer="Monogramm Maintainers <opensource at monogramm dot io>"

# Build environments
ENV FRAPPE_USER=frappe \
	BENCH_BRANCH=master \
	FRAPPE_BRANCH=v11.1.31

RUN groupadd -r $FRAPPE_USER; \
    useradd -r -m -g $FRAPPE_USER $FRAPPE_USER; \
    echo 'frappe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers

USER $FRAPPE_USER
WORKDIR /home/$FRAPPE_USER

# Setup Frappe folders
RUN set -ex; \
    git clone -b $BENCH_BRANCH --depth 1 https://github.com/frappe/bench bench-repo; \
    sudo pip install -e /home/$FRAPPE_USER/bench-repo --no-cache-dir; \
    mkdir -p frappe-bench; \
    cd frappe-bench; \
    mkdir -p apps logs sites/localhost config; \
    bench setup env; \
    sudo bench setup sudoers $FRAPPE_USER; \
    bench setup socketio
    #bench get-app frappe https://github.com/frappe/frappe --branch $FRAPPE_BRANCH

WORKDIR /home/$FRAPPE_USER/frappe-bench

# Copy docker entrypoint and set permissions
ADD ./docker-entrypoint.sh /entrypoint.sh
RUN sudo chmod +x /entrypoint.sh

VOLUME /home/$FRAPPE_USER/frappe-bench/logs

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]
