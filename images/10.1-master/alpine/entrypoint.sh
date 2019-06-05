#!/bin/sh
set -eo pipefail

# Container node type. Can be set by command argument or env var
NODE_TYPE=${NODE_TYPE:-${1}}

# Frappe working directory (frappe user set at build time)
FRAPPE_WD="/home/${FRAPPE_USER}/frappe-bench"

# -------------------------------------------------------------------
# Frappe Bench management functions

pip_install() {
  echo "Install apps python packages..."

  cd "${FRAPPE_WD}"
  ls apps/ | while read -r file; do  if [ "$file" != "frappe" ] && [ -f "apps/$file/setup.py" ]; then ./env/bin/pip install -q -e "apps/$file" --no-cache-dir; fi; done

  echo "Apps python packages installed"
}

wait_db() {
  echo "Waiting for DB at ${DB_HOST}:${DB_PORT} to start up..."
  dockerize -wait \
    "tcp://${DB_HOST}:${DB_PORT}" \
    -timeout 120s
}

wait_apps() {
  echo "Waiting for frappe apps to be set..."

  i=1
  s=10
  l=120
  while [ ! -f "${FRAPPE_WD}/sites/apps.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; do
      echo "Waiting..."
      sleep $s

      i="$(($i+$s))"
      if [[ $i = $l ]]; then
          echo 'Condition was not met in time!'
          exit 1
      fi
  done
}

wait_sites() {
  echo "Waiting for frappe current site to be set..."

  i=1
  s=10
  l=120
  while [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]; do
      echo "Waiting..."
      sleep $s

      i="$(($i+$s))"
      if [[ $i = $l ]]; then
          echo 'Condition was not met in time!'
          exit 1
      fi
  done
}

bench_app() {
  echo "Checking diagnostic info..."
  bench doctor \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"

  echo "Starting app..."
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
  echo "FIXME Setup existing apps..."

  # FIXME Error: No such command "install-app"
  #cd "${FRAPPE_WD}"
  #ls apps/ | while read -r file; do  if [ "$file" != "frappe" ]; then bench install-app "$file"; fi; done

  echo "Setup Finished"
}

bench_setup() {
  # Expecting first parameter to be the app
  FRAPPE_APP_SETUP=${1}
  if [ -n "${FRAPPE_APP_SETUP}" ]; then
    # FIXME Error: No such command "reinstall"
    echo "FIXME Reinstalling with fresh database..."
    #bench reinstall --yes

    # FIXME Error: No such command "install-app"
    echo "FIXME Installing ${FRAPPE_APP_SETUP}..."
    #bench install-app "${FRAPPE_APP_SETUP}"
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
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_worker() {
  echo "Starting $1 worker..."
  bench worker --queue "$1" \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_socketio() {
  echo "Starting socketio..."
  node "${FRAPPE_WD}/apps/frappe/socketio.js" \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}


# -------------------------------------------------------------------
# Runtime


if [ -n "${FRAPPE_RESET_SITES}" ]; then
  echo "Removing sites: ${FRAPPE_RESET_SITES}"
  rm -rf "${FRAPPE_WD}/sites/${FRAPPE_RESET_SITES}"
fi


echo "Setup folders and files owner to ${FRAPPE_USER}..."
sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
  "${FRAPPE_WD}/sites" \
  "${FRAPPE_WD}/logs"


# Frappe automatic app init
if [ -n "${FRAPPE_APP_INIT}" ]; then

  # Init apps
  if [ ! -f "${FRAPPE_WD}/sites/apps.txt" ]; then
    echo "Adding frappe to apps.txt..."
    echo "frappe" > "${FRAPPE_WD}/sites/apps.txt"

    echo "Adding ${FRAPPE_APP_INIT} to apps.txt..."
    echo "${FRAPPE_APP_INIT}" >> "${FRAPPE_WD}/sites/apps.txt"
  fi

else
  # Wait for another node to setup apps and sites
  wait_apps
fi



# Frappe automatic site setup
if [ -n "${FRAPPE_DEFAULT_SITE}" ] && [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]; then

  echo "Creating default directories for sites/${FRAPPE_DEFAULT_SITE}..."
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
    echo "Creating common site config..."
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
    echo "Creating ${FRAPPE_DEFAULT_SITE} site config from common config..."
    cp \
      "${FRAPPE_WD}/sites/common_site_config.json" \
      "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/site_config.json"
  fi

  # FIXME Error: No such command "new-site"
  echo "FIXME Creating new site at ${FRAPPE_DEFAULT_SITE}..."
  #bench new-site "${FRAPPE_DEFAULT_SITE}"

  # Init current site
  echo "Setting ${FRAPPE_DEFAULT_SITE} as current site..."
  echo "${FRAPPE_DEFAULT_SITE}" > "${FRAPPE_WD}/sites/currentsite.txt"

  # FIXME Error: No such command "use"
  echo "FIXME Using site at ${FRAPPE_DEFAULT_SITE}..."
  #bench use "${FRAPPE_DEFAULT_SITE}"

  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-site-init"
  echo "Docker Frappe automatic site setup ended"
else
  # Wait for another node to setup sites
  wait_sites
fi



# Frappe automatic app setup
if [ -n "${FRAPPE_APP_INIT}" ] && [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; then

  # Call bench setup for app
  bench_setup "${FRAPPE_APP_INIT}"

  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-app-init"
  echo "Docker Frappe automatic app setup ended"

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
