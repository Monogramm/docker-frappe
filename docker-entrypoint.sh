#!/bin/sh
set -eo pipefail

# Container node type. Can be set by command argument or env var
NODE_TYPE=${NODE_TYPE:-${1:-cli}}


# -------------------------------------------------------------------
# Frappe Bench management functions

pip_install() {
  echo "Install apps python packages..."
  cd "/home/${FRAPPE_USER}/frappe-bench"
  ls apps/ | while read -r file; do  if [ "$file" != "frappe" ]; then ./env/bin/pip install -q -e "apps/$file" --no-cache-dir; fi; done
}

wait_db() {
  echo "Waiting for DB at ${DB_HOST}:${DB_PORT} to start up..."
  dockerize -wait "tcp://${DB_HOST}:${DB_PORT}" -timeout 120s
}

bench_app() {
  echo "Checking diagnostic info about ${FRAPPE_DEFAULT_SITE}..."
  bench --site "${FRAPPE_DEFAULT_SITE}" doctor > /dev/null 2>&1

  echo "Starting app..."
  cd "/home/${FRAPPE_USER}/frappe-bench/sites"
  "/home/${FRAPPE_USER}/frappe-bench/env/bin/gunicorn" \
    -b 0.0.0.0:8000 \
    -w 4 \
    -t 120 \
    frappe.app:application --preload \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.err.log"
}

bench_setup_apps() {
  echo "Setup existing apps..."
  cd "/home/${FRAPPE_USER}/frappe-bench"
  ls apps/ | while read -r file; do  if [ "$file" != "frappe" ]; then bench install-app "$file"; fi; done
  echo "Setup Finished"
}

bench_setup() {
  # Expecting first parameter to be the app
  FRAPPE_APP_SETUP=${1}
  if [ -n "${FRAPPE_APP_SETUP}" ]; then
    echo "Reinstalling with fresh database..."
    bench reinstall --yes

    echo "Installing ${FRAPPE_APP_SETUP}..."
    bench install-app "${FRAPPE_APP_SETUP}"
  else
    echo "No app specified to reinstall"
  fi

  bench_setup_apps
}

bench_update() {
  echo "Starting update..."
  bench update --no-git
  echo "Update Finished"
}

bench_backup() {
  echo "Starting backup..."
  bench backup
  echo "Backup Finished"
}

bench_restore() {
  i=1
  for file in "sites/${FRAPPE_DEFAULT_SITE}/private/backups/*"
  do
      echo "$i $file"
      i="$(($i+1))"
  done

  read -p "Enter the number of file which you want to restore : " n
  i=1
  for file in "sites/${FRAPPE_DEFAULT_SITE}/private/backups/*"
  do
      if [ "$n" = "$i" ]; then
        echo "You have choosed $i $file"
        echo "Please wait ..."
        bench --force restore $file
      fi;
      i="$(($i+1))"
  done
}

bench_migrate() {
  echo "Starting migration..."
  bench migrate
  echo "Migrate Finished"
}

bench_scheduler() {
  echo "Starting scheduler..."
  bench schedule \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.err.log"
}

bench_worker() {
  echo "Starting $1 worker..."
  bench worker --queue "$1" \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.err.log"
}

bench_socketio() {
  echo "Starting socketio..."
  node "/home/${FRAPPE_USER}/frappe-bench/apps/frappe/socketio.js" \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "/home/${FRAPPE_USER}/frappe-bench/logs/${NODE_TYPE}.err.log"
}


# -------------------------------------------------------------------
# Runtime

# pip install of apps
pip_install

# Frappe automatic app setup
if [ -n "${FRAPPE_APP_INIT}" ] && [ ! -f "/home/${FRAPPE_USER}/frappe-bench/sites/.docker-init" ]; then

  echo "Creating default directories for sites/${FRAPPE_DEFAULT_SITE}..."
  mkdir -p \
      sites/assets \
      "sites/${FRAPPE_DEFAULT_SITE}/error-snapshots" \
      "sites/${FRAPPE_DEFAULT_SITE}/locks" \
      "sites/${FRAPPE_DEFAULT_SITE}/private/backups" \
      "sites/${FRAPPE_DEFAULT_SITE}/private/files" \
      "sites/${FRAPPE_DEFAULT_SITE}/public/files" \
      "sites/${FRAPPE_DEFAULT_SITE}/tasks-logs" \
  ;

  if [ ! -f "/home/${FRAPPE_USER}/frappe-bench/sites/common_site_config.json" ]; then
    echo "Creating common site config..."
    echo <<EOF > /home/${FRAPPE_USER}/frappe-bench/sites/common_site_config.json
{
  "admin_password": "${ADMIN_PASSWORD}",
  "encryption_key": "${ENCRYPTION_KEY}",
  "deny_multiple_logins": false,
  "disable_website_cache": false,
  "dns_multitenant": true,
  "host_name": "${FRAPPE_DEFAULT_SITE}",
  "serve_default_site": true,
  "frappe_user": "${FRAPPE_USER}",
  "auto_update": false,
  "update_bench_on_update": true,
  "shallow_clone": true,
  "rebase_on_pull": false,
  "logging": "${FRAPPE_LOGGING}",
  "db_host": "${DB_HOST}",
  "db_name": "${DB_NAME}",
  "db_user": "${DB_USER}",
  "db_password": "${DB_PASSWORD}",
  "root_password": "${DB_ROOT_PASSWORD}",
  "mail_server": "${MAIL_HOST}",
  "mail_port": "${MAIL_PORT}",
  "use_ssl": "${MAIL_USE_SSL}",
  "mail_login": "${MAIL_LOGIN}",
  "mail_password": "${MAIL_PASSWORD}",
  "redis_cache": "redis://${REDIS_CACHE_HOST}",
  "redis_queue": "redis://${REDIS_QUEUE_HOST}",
  "redis_socketio": "redis://${REDIS_SOCKETIO_HOST}",
}
EOF
  fi

  # Check default site config config
  if [ ! -f "/home/${FRAPPE_USER}/frappe-bench/sites/${FRAPPE_DEFAULT_SITE}/site_config.json" ]; then
    echo "Creating ${FRAPPE_DEFAULT_SITE} site config from common config..."
    cp \
      "/home/${FRAPPE_USER}/frappe-bench/sites/common_site_config.json" \
      "/home/${FRAPPE_USER}/frappe-bench/sites/${FRAPPE_DEFAULT_SITE}/site_config.json"
  fi

  echo "Setup folders and files owner to ${FRAPPE_USER}..."
  sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
    "/home/${FRAPPE_USER}/frappe-bench/sites/sites/*" \
    "/home/${FRAPPE_USER}/frappe-bench/sites/logs/*"


  echo "Creating new site at ${FRAPPE_DEFAULT_SITE}..."
  bench new-site "${FRAPPE_DEFAULT_SITE}"
  echo "Using site at ${FRAPPE_DEFAULT_SITE}..."
  bench use "${FRAPPE_DEFAULT_SITE}"


  # Call bench setup
  bench_setup "${FRAPPE_APP_INIT}"


  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "/home/${FRAPPE_USER}/frappe-bench/sites/.docker-init"
  echo "Docker Frappe automatic setup ended"

else
  echo "Using site at ${FRAPPE_DEFAULT_SITE}..."
  bench use "${FRAPPE_DEFAULT_SITE}"
fi

# Check current site
if [ ! -f "/home/${FRAPPE_USER}/frappe-bench/sites/currentsite.txt" ]; then
  echo "Setting ${FRAPPE_DEFAULT_SITE} as current site..."
  echo "${FRAPPE_DEFAULT_SITE}" > "/home/${FRAPPE_USER}/frappe-bench/sites/currentsite.txt"
fi

# Execute task based on node type
case "${NODE_TYPE}" in
  ("app") wait_db; bench_app ;;
  ("setup") bench_setup ${@:2} ;;
  ("setup-apps") bench_setup_apps ;;
  ("update") bench_update ;;
  ("backup") bench_backup;;
  ("restore") bench_restore ;;
  ("migrate") bench_migrate ;;
  ("scheduler") bench_scheduler ;;
  ("worker-default") bench_worker default ;;
  ("worker-long") bench_worker long ;;
  ("worker-short") bench_worker short ;;
  ("node-socketio") bench_socketio ;;
  ("cli") bench ${@:2} ;;
  (*) ;;
esac
