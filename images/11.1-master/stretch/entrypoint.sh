#!/bin/sh
set -e

NODE_TYPE=${1}
APP=${2}

# TODO Pipe some commands output to logs
# | tee /home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.log) 3>&1 1>&2 2>&3 | tee /home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.err.log

pip_install() {
  echo 'Install apps...'
  cd /home/${FRAPPE_USER}/frappe-bench
  ls apps/ | while read -r file; do  if [ $file != "frappe" ]; then ./env/bin/pip install -q -e apps/$file --no-cache-dir; fi; done && \
}

wait_db() {
  echo "Waiting for DB at ${DB_HOST}:${DB_PORT} to start up..."
  dockerize -wait "tcp://${DB_HOST}:${DB_PORT}" -timeout 120s
}

bench_app() {
  echo "Starting app..."
  cd /home/${FRAPPE_USER}/frappe-bench/sites
  /home/${FRAPPE_USER}/frappe-bench/env/bin/gunicorn \
    -b 0.0.0.0:8000 \
    -w 4 \
    -t 120 \
    frappe.app:application --preload
}

bench_setup_apps() {
  ls apps/ | while read -r file; do  if [ $file != "frappe" ]; then bench install-app $file; fi; done
  echo "Setup Finished"
}

bench_setup() {
  bench reinstall --yes && bench install-app $APP && bench_setup_apps
}

bench_update() {
  bench update --no-git
  echo "Update Finished"
}

bench_backup() {
  bench backup
  echo "Backup Finished"
}

bench_restore() {
  i=1
  for file in sites/localhost/private/backups/*
  do
      echo "$i $file"
      i=$(($i+1))
  done
  read -p "Enter the number of file which you want to restore : " n
  i=1
  for file in sites/localhost/private/backups/*
  do
      if [ $n = $i ]; then
        echo "You have choosed $i $file"
        echo "Please wait ..."
        bench --force restore $file
      fi;
      i=$(($i+1))
  done
}

bench_migrate() {
  bench migrate
  echo "Migrate Finished"
}

bench_scheduler() {
  echo "Starting scheduler..."
  bench schedule
}

bench_worker() {
  echo "Starting $1 worker..."
  bench worker --queue $1
}

bench_socketio() {
  echo "Starting socketio..."
  node /home/${FRAPPE_USER}/frappe-bench/apps/frappe/socketio.js
}

pip_install

# Frappe automatic setup
if [ -n "${FRAPPE_DOCKER_INIT}" ] && [ ! -f /home/${FRAPPE_USER}/frappe-bench/sites/.docker-init ]; then

  echo 'Creating default directories for sites/localhost...'
  mkdir -p \
      sites/assets \
      sites/localhost/error-snapshots \
      sites/localhost/locks \
      sites/localhost/private/backups \
      sites/localhost/private/files \
      sites/localhost/public/files \
      sites/localhost/tasks-logs \
  ;

  if [ ! -f /home/${FRAPPE_USER}/frappe-bench/sites/common_site_config.json ]; then
    echo 'Creating common site config...'
    echo <<EOF > /home/${FRAPPE_USER}/frappe-bench/sites/common_site_config.json
{
  "admin_password": "${ADMIN_PASSWORD}",
  "db_host": "${DB_HOST}",
  "db_name": "${DB_NAME}",
  "db_user": "${DB_USER}",
  "db_password": "${DB_PASSWORD}",
  "root_password": "${ROOT_PASSWORD}",
  "encryption_key": "${ENCRYPTION_KEY}",
  "deny_multiple_logins": false,
  "disable_website_cache": false,
  "dns_multitenant": false,
  "host_name": "localhost",
  "logging": "1",
  "redis_cache": "redis://erpnext_redis_cache",
  "redis_queue": "redis://erpnext_redis_queue",
  "redis_socketio": "redis://erpnext_redis_socketio",
  "serve_default_site": true,
  "mail_server": "${MAIL_HOST}",
  "mail_port": "${MAIL_PORT}",
  "use_ssl": "${MAIL_USE_SSL}",
  "mail_login": "${MAIL_LOGIN}",
  "mail_password": "${MAIL_PASSWORD}",
}
EOF
  fi

  # Check localhost config
  if [ ! -f /home/${FRAPPE_USER}/frappe-bench/sites/localhost/site_config.json ]; then
    echo 'Creating localhost site config from common config...'
    cp \
      /home/${FRAPPE_USER}/frappe-bench/sites/common_site_config.json \
      /home/${FRAPPE_USER}/frappe-bench/sites/localhost/site_config.json
  fi

  # Check current site
  if [ ! -f /home/${FRAPPE_USER}/frappe-bench/sites/currentsite.txt ]; then
    echo 'Setting localhost as current site...'
    echo localhost > /home/${FRAPPE_USER}/frappe-bench/sites/currentsite.txt
  fi

  # TODO
  #echo 'Retrieve frappe app...'
  #bench get-app frappe https://github.com/frappe/frappe --branch $FRAPPE_BRANCH
  #echo 'Setting new site...'
  #bench new-site localhost
  #echo "Installing app ${FRAPPE_DOCKER_INIT} on localhost..."
  #bench --site localhost install-app ${FRAPPE_DOCKER_INIT}

  # Call bench setup
  bench_setup

  echo 'Docker Frappe automatic setup ended'
  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > /home/${FRAPPE_USER}/frappe-bench/sites/.docker-init

fi

# Execute task based on node type
case "$NODE_TYPE" in
  ("app") wait_db; bench_app ;;
  ("setup") wait_db; bench_setup ;;
  ("setup-apps") wait_db; bench_setup_apps ;;
  ("update") wait_db; bench_update ;;
  ("backup") wait_db; bench_backup;;
  ("restore") wait_db; bench_restore ;;
  ("migrate") wait_db; bench_migrate ;;
  ("scheduler") bench_scheduler ;;
  ("worker-default") bench_worker default ;;
  ("worker-long") bench_worker long ;;
  ("worker-short") bench_worker short ;;
  ("node-socketio") bench_socketio ;;
  ("cli") bench ${@:2} ;;
  (*) ;;
esac
