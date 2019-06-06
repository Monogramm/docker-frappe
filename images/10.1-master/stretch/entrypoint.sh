#!/bin/sh
set -e

# Container node type. Can be set by command argument or env var
NODE_TYPE=${NODE_TYPE:-${1}}

# Frappe working directory (frappe user set at build time)
FRAPPE_WD="/home/${FRAPPE_USER}/frappe-bench"

# -------------------------------------------------------------------
# Frappe Bench management functions

log() {
  echo "[${NODE_TYPE}] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@"
}

pip_install() {
  log "Install apps python packages..."

  cd "${FRAPPE_WD}"
  ls apps/ | while read -r file; do  if [ "$file" != "frappe" ] && [ -f "apps/$file/setup.py" ]; then ./env/bin/pip install -q -e "apps/$file" --no-cache-dir; fi; done

  log "Apps python packages installed"
}

wait_db() {
  log "Waiting for DB at ${DB_HOST}:${DB_PORT} to start up..."
  dockerize -wait \
    "tcp://${DB_HOST}:${DB_PORT}" \
    -timeout 120s
}

wait_apps() {
  log "Waiting for frappe apps to be set..."

  i=0
  s=10
  l=600
  while [ ! -f "${FRAPPE_WD}/sites/apps.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; do
      log "Waiting..."
      sleep $s

      i="$(($i+$s))"
      if [[ $i = $l ]]; then
          log 'Condition was not met in time!'
          exit 1
      fi
  done
}

wait_sites() {
  log "Waiting for frappe current site to be set..."

  i=0
  s=10
  l=1800
  while [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]; do
      log "Waiting..."
      sleep $s

      i="$(($i+$s))"
      if [[ $i = $l ]]; then
          log 'Condition was not met in time!'
          exit 1
      fi
  done
}

bench_app() {
  log "Checking diagnostic info..."
  bench doctor \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"

  log "Starting app..."
  cd "${FRAPPE_WD}/sites"
  "${FRAPPE_WD}/env/bin/gunicorn" \
    -b 0.0.0.0:8000 \
    -w 4 \
    -t 120 \
    frappe.app:application --preload \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_setup_apps() {
  log "Setup existing apps..."

  cd "${FRAPPE_WD}"
  ls apps/ | while read -r file; do  if [ "$file" != "frappe" ]; then bench install-app "$file"; fi; done

  bench build

  log "Setup Finished"
}

bench_setup() {
  # Expecting first parameter to be the app
  FRAPPE_APP_SETUP=${1}
  if [ -n "${FRAPPE_APP_SETUP}" ]; then
    wait_db

    log "Reinstalling with fresh database..."
    bench reinstall --yes

    log "Installing ${FRAPPE_APP_SETUP}..."
    bench install-app "${FRAPPE_APP_SETUP}"
  else
    log "No app specified to reinstall"
  fi

  bench_setup_apps
}

bench_update() {
  log "Starting update..."
  bench update --no-git
  log "Update Finished"
}

bench_backup() {
  log "Starting backup..."
  bench backup
  log "Backup Finished"
}

bench_restore() {
  i=1
  for file in "sites/${FRAPPE_DEFAULT_SITE}/private/backups/*"
  do
      log "$i $file"
      i="$(($i+1))"
  done

  read -p "Enter the number of file which you want to restore : " n
  i=1
  for file in "sites/${FRAPPE_DEFAULT_SITE}/private/backups/*"
  do
      if [ "$n" = "$i" ]; then
        log "You have choosed $i $file"
        log "Please wait ..."
        bench --force restore $file
      fi;
      i="$(($i+1))"
  done
}

bench_migrate() {
  log "Starting migration..."
  bench migrate
  log "Migrate Finished"
}

bench_scheduler() {
  log "Starting scheduler..."
  bench schedule \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_worker() {
  log "Starting $1 worker..."
  bench worker --queue "$1" \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_socketio() {
  log "Starting socketio..."
  node "${FRAPPE_WD}/apps/frappe/socketio.js" \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}


# -------------------------------------------------------------------
# Runtime


if [ -n "${FRAPPE_RESET_SITES}" ]; then
  log "Removing sites: ${FRAPPE_RESET_SITES}"
  rm -rf "${FRAPPE_WD}/sites/${FRAPPE_RESET_SITES}"
fi


log "Setup folders and files owner to ${FRAPPE_USER}..."
sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
  "${FRAPPE_WD}/sites" \
  "${FRAPPE_WD}/logs"


# Frappe automatic app init
if [ -n "${FRAPPE_APP_INIT}" ]; then

  # Init apps
  if [ ! -f "${FRAPPE_WD}/sites/apps.txt" ]; then
    log "Adding frappe to apps.txt..."
    echo "frappe" > "${FRAPPE_WD}/sites/apps.txt"

    log "Adding ${FRAPPE_APP_INIT} to apps.txt..."
    echo "${FRAPPE_APP_INIT}" >> "${FRAPPE_WD}/sites/apps.txt"
  fi

else
  # Wait for another node to setup apps and sites
  wait_apps
fi



# Frappe automatic site setup
if [ -n "${FRAPPE_DEFAULT_SITE}" ] && [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]; then

  log "Creating default directories for sites/${FRAPPE_DEFAULT_SITE}..."
  mkdir -p \
      "${FRAPPE_WD}/sites/assets" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/error-snapshots" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/locks" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/files" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/public/files" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/tasks-logs" \
  ;

  # Init common site config
  if [ ! -f "${FRAPPE_WD}/sites/common_site_config.json" ]; then
    log "Creating common site config..."
    cat <<EOF > "${FRAPPE_WD}/sites/common_site_config.json"
{
  "admin_password": "${ADMIN_PASSWORD}",
  "encryption_key": "${ENCRYPTION_KEY}",
  "deny_multiple_logins": false,
  "disable_website_cache": false,
  "dns_multitenant": false,
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
  "mute_emails": ${MAIL_MUTED},
  "redis_cache": "redis://${REDIS_CACHE_HOST}",
  "redis_queue": "redis://${REDIS_QUEUE_HOST}",
  "redis_socketio": "redis://${REDIS_SOCKETIO_HOST}"
}
EOF
  fi

  # Check default site config
  if [ ! -f "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/site_config.json" ]; then
    log "Creating ${FRAPPE_DEFAULT_SITE} site config from common config..."
    cp \
      "${FRAPPE_WD}/sites/common_site_config.json" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/site_config.json"
  fi

  # Init current site
  if [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ]; then
    wait_db

    log "Creating new site at ${FRAPPE_DEFAULT_SITE}..."
    bench new-site "${FRAPPE_DEFAULT_SITE}" --db-type ${DB_TYPE}

    log "Setting ${FRAPPE_DEFAULT_SITE} as current site..."
    echo "${FRAPPE_DEFAULT_SITE}" > "${FRAPPE_WD}/sites/currentsite.txt"
  fi

  log "Using site at ${FRAPPE_DEFAULT_SITE}..."
  bench use "${FRAPPE_DEFAULT_SITE}"

  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-site-init"
  log "Docker Frappe automatic site setup ended"
else
  # Wait for another node to setup sites
  wait_sites
fi



# Frappe automatic app setup
if [ -n "${FRAPPE_APP_INIT}" ] && [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; then

  # Call bench setup for app
  bench_setup "${FRAPPE_APP_INIT}"

  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-app-init"
  log "Docker Frappe automatic app setup ended"

fi



# Execute task based on node type
case "${NODE_TYPE}" in
  ("app") wait_db; pip_install; bench_app ;;
  ("setup") pip_install; bench_setup ${@:2} ;;
  ("setup-apps") pip_install; bench_setup_apps ;;
  ("update") bench_update ;;
  ("backup") bench_backup;;
  ("restore") bench_restore ;;
  ("migrate") bench_migrate ;;
  ("scheduler") bench_scheduler ;;
  ("worker-default") bench_worker default ;;
  ("worker-long") bench_worker long ;;
  ("worker-short") bench_worker short ;;
  ("node-socketio") bench_socketio ;;
  (*) ;;
esac
