#!/bin/sh
set -e

# Container node type. Can be set by command argument or env var
NODE_TYPE=${NODE_TYPE:-${1}}

# Frappe user
FRAPPE_USER=${FRAPPE_USER:-frappe}
# Frappe working directory
FRAPPE_WD="/home/${FRAPPE_USER}/frappe-bench"

# -------------------------------------------------------------------
# Frappe Bench management functions

log() {
  echo "[${NODE_TYPE}] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@"
}

display_logs() {
  tail -n 100 "${FRAPPE_WD}/logs/"*.log
}

setup_log_owner() {
  log "Setup logs folders and files owner to ${FRAPPE_USER}..."
  sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
    "${FRAPPE_WD}/logs" \
  ;
}

setup_sites_owner() {
  # FIXME New bug with Debian where owners is not set properly...
  log "Setup sites folders and files owner to ${FRAPPE_USER}..."
  sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
    "${FRAPPE_WD}/sites" \
  ;
}


pip_install() {
  log "Install apps python packages..."

  cd "${FRAPPE_WD}"
  ls apps/ | while read -r file; do  if [ "$file" != "frappe" ] && [ -f "apps/$file/setup.py" ]; then ./env/bin/pip%%PIP_VERSION%% install -q -e "apps/$file" --no-cache-dir; fi; done

  log "Apps python packages installed"
}

wait_db() {
  log "Waiting for DB at ${DB_HOST}:${DB_PORT} to start up..."
  dockerize -wait \
    "tcp://${DB_HOST}:${DB_PORT}" \
    -timeout "${DOCKER_DB_TIMEOUT}s"
}

wait_apps() {
  log "Waiting for frappe apps to be set..."

  i=0
  s=10
  l=${DOCKER_APPS_TIMEOUT}
  while [ ! -f "${FRAPPE_WD}/sites/apps.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; do
      log "Waiting apps..."
      sleep "$s"

      i="$(($i+$s))"
      if [ "$i" = "$l" ]; then
          log 'Apps were not set in time!'
          log 'Check the following logs for details:'
          display_logs
          exit 1
      fi
  done
}

wait_sites() {
  log "Waiting for frappe current site to be set..."

  i=0
  s=10
  l=${DOCKER_SITES_TIMEOUT}
  while [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]; do
      log "Waiting site..."
      sleep "$s"

      i="$(($i+$s))"
      if [ "$i" = "$l" ]; then
          log 'Site was not set in time!'
          log 'Check the following logs for details:'
          display_logs
          exit 1
      fi
  done
}

wait_container() {
  log "Waiting for docker container init..."

  i=0
  s=10
  l=${DOCKER_INIT_TIMEOUT}
  while [ ! -f "${FRAPPE_WD}/sites/.docker-init" ]; do
      log "Waiting init..."
      sleep "$s"

      i="$(($i+$s))"
      if [ "$i" = "$l" ]; then
          log 'Container was not initialized in time!'
          log 'Check the following logs for details:'
          display_logs
          exit 1
      fi
  done
}

bench_doctor() {
  log "Checking diagnostic info..."
  bench doctor \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_app() {
  bench_doctor


  log "Starting app on port ${DOCKER_GUNICORN_PORT}..."
  cd "${FRAPPE_WD}/sites"

  GUNICORN_ARGS="-t ${DOCKER_GUNICORN_TIMEOUT} --workers ${DOCKER_GUNICORN_WORKERS} --bind ${DOCKER_GUNICORN_BIND_ADDRESS}:${DOCKER_GUNICORN_PORT} --log-level ${DOCKER_GUNICORN_LOGLEVEL}"

  if [ -n  "${DOCKER_GUNICORN_CERTFILE}" ]; then
    GUNICORN_ARGS="${DOCKER_GUNICORN_ARGS} --certfile=${DOCKER_GUNICORN_CERTFILE}"
  fi

  if [ -n  "${DOCKER_GUNICORN_KEYFILE}" ]; then
    GUNICORN_ARGS="${DOCKER_GUNICORN_ARGS} --keyfile=${DOCKER_GUNICORN_KEYFILE}"
  fi

  "${FRAPPE_WD}/env/bin/gunicorn" \
     $GUNICORN_ARGS \
    frappe.app:application --preload \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_build_apps() {
  log "Building apps assets..."
  bench build
  log "Apps assets build Finished"
}

bench_setup_database() {
  log "Setup database..."

  if [ "${DB_TYPE}" = "mariadb" ] && [ -n "${DOCKER_DB_ALLOWED_HOSTS}" ]; then
    log "Updating MariaDB users allowed hosts..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" \
          -u "${DB_ROOT_LOGIN}" -p${DB_ROOT_PASSWORD} \
          "${DB_NAME}" \
          -e "UPDATE mysql.user SET host = '${DOCKER_DB_ALLOWED_HOSTS}' WHERE host LIKE '%.%.%.%' AND user != 'root';"

    log "Updating MariaDB databases allowed hosts..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" \
          -u "${DB_ROOT_LOGIN}" -p${DB_ROOT_PASSWORD} \
          "${DB_NAME}" \
          -e "UPDATE mysql.db SET host = '${DOCKER_DB_ALLOWED_HOSTS}' WHERE host LIKE '%.%.%.%' AND user != 'root';"

    log "Flushing MariaDB privileges..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" \
          -u "${DB_ROOT_LOGIN}" -p${DB_ROOT_PASSWORD} \
          "${DB_NAME}" \
          -e "FLUSH PRIVILEGES;"
  fi

  log "Database setup Finished"
}

bench_setup() {
  # Expecting parameters to be a list of apps to (re)install
  if [ "$#" -ne 0 ] || [ -n "${FRAPPE_REINSTALL_DATABASE}" ]; then
    wait_db

    log "Reinstalling with fresh database..."
    bench reinstall --yes

    for app in $@; do
      log "Installing app $app..."
      bench install-app "$app"
    done
  else
    log "No app specified to reinstall"
  fi

  bench_build_apps
  bench_setup_database
}

bench_update() {
  setup_log_owner
  log "Starting update..."
  bench update $@
  log "Update Finished"
}

list_backups() {
  if [ -d "sites/${FRAPPE_DEFAULT_SITE}/private/backups" ]; then
    log "Available backups:"
    i=1
    for file in "sites/${FRAPPE_DEFAULT_SITE}"/private/backups/*
    do
      log "    $i. $file"
      i="$(($i+1))"
    done
  else
    log "No available backups."
  fi
}

bench_backup() {
  setup_log_owner
  log "Starting backup..."
  bench backup $@
  log "Backup Finished."
  list_backups
}

bench_restore() {
  setup_log_owner

  if [ "$#" -eq 0 ]; then
    list_backups
    # Choose file number
    read -p "Enter the file number which you want to restore : " n
  else
    # Get file number from argument
    n=$1
  fi
  log "You have chosen to restore backup file number $n"

  i=1
  for file in "sites/${FRAPPE_DEFAULT_SITE}"/private/backups/*
  do
    if [ "$n" = "$i" ]; then
      log "Restoring backup file number $n: $file. Please wait..."
      bench --force restore $file
      break
    fi;
    i="$(($i+1))"
  done

  if [ "$n" = "$i" ]; then
    log "Backup successfully restored."
  else
    log "Requested backup was not found!"
    exit 1
  fi
}

bench_setup_requirements() {
  setup_log_owner
  log "Starting setup of requirements..."
  bench setup requirements $@
  log "Requirements setup Finished"
}

bench_migrate() {
  setup_log_owner
  log "Starting migration..."
  bench migrate $@
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

setup_log_owner


# Frappe automatic app init
if [ -n "${FRAPPE_APP_INIT}" ]; then

  setup_sites_owner

  # Init apps
  if [ ! -f "${FRAPPE_WD}/sites/apps.txt" ]; then
    log "Adding frappe to apps.txt..."
    sudo touch "${FRAPPE_WD}/sites/apps.txt"
    sudo chown "${FRAPPE_USER}:${FRAPPE_USER}" \
      "${FRAPPE_WD}/sites/apps.txt" \
    ;
    echo "frappe" > "${FRAPPE_WD}/sites/apps.txt"
  fi

  for app in ${FRAPPE_APP_INIT}; do
    if ! grep -q "^${app}$" "${FRAPPE_WD}/sites/apps.txt"; then
      log "Adding $app to apps.txt..."
      echo "$app" >> "${FRAPPE_WD}/sites/apps.txt"
    fi
  done

  # TODO remove anything from apps.txt which is not in apps folder?

else
  # Wait for another node to setup apps and sites
  wait_sites
  wait_apps
  wait_container
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
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/task-logs" \
  ;
  sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
    "${FRAPPE_WD}/sites/assets" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/error-snapshots" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/locks" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/files" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/public/files" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/tasks-logs" \
    "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/task-logs" \
  ;

  # Init common site config
  if [ ! -f "${FRAPPE_WD}/sites/common_site_config.json" ]; then
    log "Creating common site config..."
    sudo touch "${FRAPPE_WD}/sites/common_site_config.json"
    sudo chown "${FRAPPE_USER}:${FRAPPE_USER}" \
      "${FRAPPE_WD}/sites/common_site_config.json" \
    ;
    cat <<EOF > "${FRAPPE_WD}/sites/common_site_config.json"
{
  "google_analytics_id": "${GOOGLE_ANALYTICS_ID}",
  "developer_mode": ${DEVELOPER_MODE},
  "admin_password": "${ADMIN_PASSWORD}",
  "encryption_key": "${ENCRYPTION_KEY:-$(openssl rand -base64 32)}",
  "deny_multiple_logins": false,
  "disable_website_cache": false,
  "dns_multitenant": false,
  "host_name": "${FRAPPE_DEFAULT_PROTOCOL}${FRAPPE_DEFAULT_SITE}",
  "serve_default_site": true,
  "frappe_user": "${FRAPPE_USER}",
  "auto_update": false,
  "update_bench_on_update": true,
  "shallow_clone": true,
  "rebase_on_pull": false,
  "logging": "${FRAPPE_LOGGING}",
  "db_type": "${DB_TYPE}",
  "db_host": "${DB_HOST}",
  "db_port": ${DB_PORT},
  "db_name": "${DB_NAME}",
  "db_user": "${DB_NAME}",
  "db_password": "${DB_PASSWORD}",
  "root_login": "${DB_ROOT_LOGIN}",
  "root_password": "${DB_ROOT_PASSWORD}",
  "mail_server": "${MAIL_HOST}",
  "mail_port": ${MAIL_PORT},
  "use_ssl": "${MAIL_USE_SSL}",
  "mail_login": "${MAIL_LOGIN}",
  "mail_password": "${MAIL_PASSWORD}",
  "auto_email_id": "${MAIL_EMAIL_ID}",
  "email_sender_name": "${MAIL_SENDER_NAME}",
  "always_use_account_email_id_as_sender": ${MAIL_ALWAYS_EMAIL_ID_AS_SENDER},
  "always_use_account_name_as_sender_name": ${MAIL_ALWAYS_NAME_AS_SENDER_NAME},
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
    sudo chown "${FRAPPE_USER}:${FRAPPE_USER}" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/site_config.json" \
    ;
  fi

  # Init current site
  if [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ]; then
    wait_db

    setup_sites_owner

    log "Creating new site at ${FRAPPE_DEFAULT_SITE} with ${DB_TYPE} database..."
    if [ "${DB_TYPE}" = "mariadb" ]; then
      bench new-site "${FRAPPE_DEFAULT_SITE}" \
        --force \
        --db-name ${DB_NAME} \
        --admin-password ${ADMIN_PASSWORD} \
        --mariadb-root-username ${DB_ROOT_LOGIN} \
        --mariadb-root-password "${DB_ROOT_PASSWORD}"
    else
      bench new-site "${FRAPPE_DEFAULT_SITE}" \
        --force \
        --db-name ${DB_NAME} \
        --admin-password ${ADMIN_PASSWORD}
    fi

    log "Setting ${FRAPPE_DEFAULT_SITE} as current site..."
    sudo touch "${FRAPPE_WD}/sites/currentsite.txt"
    sudo chown "${FRAPPE_USER}:${FRAPPE_USER}" \
      "${FRAPPE_WD}/sites/currentsite.txt" \
    ;
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



if [ -n "${FRAPPE_APP_INIT}" ]; then

  # Frappe automatic app setup
  if [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; then

    # Call bench setup for app
    bench_setup "${FRAPPE_APP_INIT}"

    echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-app-init"
    log "Docker Frappe automatic app setup ended"

  fi

  # Frappe automatic app migration (based on container build properties)
  if [ ! -f "${FRAPPE_WD}/sites/.docker-init" ] || ! grep "${DOCKER_TAG} ${DOCKER_VCS_REF} ${DOCKER_BUILD_DATE}" "${FRAPPE_WD}/sites/.docker-init"; then
    bench_setup_requirements
    bench_migrate
  fi
  echo "${DOCKER_TAG} ${DOCKER_VCS_REF} ${DOCKER_BUILD_DATE}" > "${FRAPPE_WD}/sites/.docker-init"

fi



# Execute task based on node type
case "${NODE_TYPE}" in
  ("doctor") wait_db; bench_doctor ;;
  ("app") wait_db; pip_install; bench_app ;;
  ("setup") pip_install; shift; bench_setup $@ ;;
  ("setup-database") bench_setup_database ;;
  ("build-apps") pip_install; bench_build_apps ;;
  ("update") shift; bench_update $@ ;;
  ("backup") shift; bench_backup $@ ;;
  ("restore") shift; bench_restore $@ ;;
  ("migrate") shift; bench_migrate $@ ;;
  ("scheduler") bench_scheduler ;;
  ("worker-default") bench_worker default ;;
  ("worker-long") bench_worker long ;;
  ("worker-short") bench_worker short ;;
  ("node-socketio") bench_socketio ;;
  (*) exec "$@" ;;
esac
