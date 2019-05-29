FROM monogramm/docker-frappe-base:alpine

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

# FIXME frappe 10 references croniter==0.3.26 which does not exist
# TODO Update requirements.txt croniter==0.3.26 to croniter==0.3.29
# Ref https://discuss.erpnext.com/t/easy-install-for-v10-no-longer-works-fails-every-time-w-same-error-multiple-os/47899/24

# FIXME ModuleNotFoundError: No module named 'pip.req' with pip 10 and bench 4.1
# TODO Downgrade pip to 9.3
# Ref https://discuss.erpnext.com/t/bench-install-on-easy-setup-failing-no-pip-req/35823/11

# FIXME Error: Cannot find module 'rollup'
# TODO Install node modules manually
# Ref https://discuss.erpnext.com/t/error-cannot-find-module-rollup/45204
# Ref https://discuss.erpnext.com/t/cannot-find-module-rollup/48989

# Setup Frappe folders
RUN set -ex; \
    git clone -b $BENCH_BRANCH --depth 1 https://github.com/frappe/bench bench-repo; \
    sudo pip install -e /home/$FRAPPE_USER/bench-repo --no-cache-dir; \
    mkdir -p frappe-bench; \
    cd frappe-bench; \
    mkdir -p apps logs sites/localhost config; \
    bench setup env; \
    bench setup requirements --node; \
    sudo bench setup sudoers $FRAPPE_USER; \
    bench setup socketio; \
    bench get-app frappe https://github.com/frappe/frappe --branch $FRAPPE_BRANCH

# Copy docker entrypoint and set permissions
ADD ./docker-entrypoint.sh /entrypoint.sh
RUN sudo chmod +x /entrypoint.sh

VOLUME /home/$FRAPPE_USER/frappe-bench/logs

WORKDIR /home/$FRAPPE_USER/frappe-bench

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]
