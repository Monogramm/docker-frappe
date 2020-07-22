#!/bin/sh
##
##    Docker image for Frappe applications.
##    Copyright (C) 2020  Monogramm
##
##    This program is free software: you can redistribute it and/or modify
##    it under the terms of the GNU Affero General Public License as published
##    by the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU Affero General Public License for more details.
##
##    You should have received a copy of the GNU Affero General Public License
##    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##
set -e

# Container node type. Can be set by command argument or env var
NODE_TYPE=${NODE_TYPE:-${1}}

# Frappe user
FRAPPE_USER=${FRAPPE_USER:-frappe}
# Frappe working directory
FRAPPE_WD="/home/${FRAPPE_USER}/frappe-bench"


# -------------------------------------------------------------------
# Frappe Bench management functions

reset_logs() {
  sudo mkdir -p "${FRAPPE_WD}/logs/";

  echo "[${NODE_TYPE}] [$(date +%Y-%m-%dT%H:%M:%S%:z)] Reset docker entrypoint logs" \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
}

log() {
  echo "[${NODE_TYPE}] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@" \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
}

display_logs() {
  if [ -d "${FRAPPE_WD}/logs/" ]; then
    sudo tail -n 100 "${FRAPPE_WD}"/logs/*.log
  else
    log "Logs directory does not exist!"
  fi
}

setup_logs_owner() {
  log "Setup logs folders and files owner to ${FRAPPE_USER}..."
  sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
    "${FRAPPE_WD}/logs" \
  ;
}

setup_sites_owner() {
  # FIXME New bug with Debian where owners is not set properly??!
  log "Setup sites folders and files owner to ${FRAPPE_USER}..."
  sudo chown -R "${FRAPPE_USER}:${FRAPPE_USER}" \
    "${FRAPPE_WD}/sites" \
  ;
}

# TODO Function to escape double quotes for variables inserted in JSON


pip_install() {
  log "Install apps python packages..."

  cd "${FRAPPE_WD}"
  ls apps/ | while read -r file; do
    if [ "$file" != "frappe" ] && [ -f "apps/$file/setup.py" ]; then
      ./env/bin/pip3 install -q -e "apps/$file" --no-cache-dir \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
    fi;
  done

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
          if [[ "${DOCKER_DEBUG}" == "1" ]]; then
            log 'Check the following logs for details:'
            display_logs
          fi
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
          if [[ "${DOCKER_DEBUG}" == "1" ]]; then
            log 'Check the following logs for details:'
            display_logs
          fi
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
          if [[ "${DOCKER_DEBUG}" == "1" ]]; then
            log 'Check the following logs for details:'
            display_logs
          fi
          exit 1
      fi
  done
}

bench_doctor() {
  setup_logs_owner

  log "Checking diagnostic info..."

  if bench doctor; then

    log "Everything seems to be good with your Frappe environment and background workers."
    # Bench Doctor might return successfully but display in logs scheduler is disabled/inactive:
    # -----Checking scheduler status-----
    # Scheduler disabled for localhost
    # Scheduler inactive for localhost
    # Workers online: 3
    # -----localhost Jobs-----

    # TODO Only enable if doctor says the scheduler is disabled/inactive
    log "Enabling schedulers for current site..."
    bench enable-scheduler \
      | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"

  else

    log "Error(s) detected in your Frappe environment and background workers!!!"
    bench doctor \
      | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"

    # Remove any module not found from bench installed apps
    for app in $(bench doctor 3>&1 1>&2 2>&3 | grep 'ModuleNotFoundError: ' | cut -d"'" -f 2); do
      if ! echo "${FRAPPE_APP_PROTECTED}" | grep -qE "(^| )${app}( |$)"; then
        log "Removing '$app' from bench..."
        bench remove-from-installed-apps "$app" \
          | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
          | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
      else
        log "The application '$app' was not found but cannot be removed because it is protected!!"
      fi
    done

  fi
}

bench_build_apps() {
  log "Building apps assets..."
  bench build ${FRAPPE_BUILD_OPTIONS} \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
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

bench_install_apps() {
  for app in $@; do
    if ! grep -q "^${app}$" "${FRAPPE_WD}/sites/apps.txt"; then
      log "Adding '$app' to apps.txt..."
      echo "$app" >> "${FRAPPE_WD}/sites/apps.txt"

      log "Installing app '$app'..."
      bench install-app "$app" \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
    fi
  done
}

bench_setup() {
  # Expecting parameters to be a list of apps to (re)install
  if [ "$#" -ne 0 ] || [[ "${FRAPPE_REINSTALL_DATABASE}" = "1" ]]; then
    wait_db

    log "Reinstalling with fresh database..."
    bench reinstall --yes \
      | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"

    bench_install_apps "$@"
  else
    log "No app specified to reinstall"
  fi

  bench_build_apps
  bench_setup_database
}

bench_update() {
  setup_logs_owner
  log "Starting update..."
  bench update $@ \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
  log "Update Finished"
}

list_backups() {
  if [ -z "${FRAPPE_DEFAULT_SITE}" ]; then
    if [ -f "${FRAPPE_WD}/sites/currentsite.txt" ]; then
      FRAPPE_DEFAULT_SITE=$(cat "${FRAPPE_WD}/sites/currentsite.txt")
    else
      log "Could not define the Frappe current site!"
      exit 1
    fi
  fi

  if [ -d "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups" ]; then
    log "Available backups for site ${FRAPPE_DEFAULT_SITE}:"
    i=1
    for file in "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}"/private/backups/*
    do
      log "    $i. $file"
      i="$((i + 1))"
    done
  else
    log "No available backups."
  fi
}

bench_backup() {
  setup_logs_owner
  log "Starting backup..."
  bench backup $@ \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
  log "Backup Finished."
  list_backups

  # Call bench doctor after backup
  bench_doctor
}

bench_restore() {
  setup_logs_owner

  if [ "$#" -eq 0 ]; then
    list_backups
    # Choose file name
    read -p "Enter the SQL file name which you want to restore: " file

    # Allow to set the private and public files archive as well
    read -p "Enter the public files archive name which you want to restore (or press enter for none): " public
    read -p "Enter the private files archive name which you want to restore (or press enter for none): " private
  else

    case ${1} in
      (*[!0-9]*|'') # Not a number: assume all args are file names
        file=$1
        public=$2
        private=$3
        ;;
      (*) # A number: assume all args are numbers
        i=1
        for f in "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}"/private/backups/*
        do
          if [ "$1" = "$i" ]; then
            file=$f
          elif [ "$2" = "$i" ]; then
            public=$f
          elif [ "$3" = "$i" ]; then
            private=$f
          fi
          i="$(($i+1))"
        done
        ;;
    esac

  fi

  # Little helpers to allow to only set the name of the files instead of path
  if [ -f "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups/${file}" ]; then
    file="${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups/${file}"
  fi
  if [ -f "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups/${public}" ]; then
    public="${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups/${public}"
  fi
  if [ -f "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups/${private}" ]; then
    private="${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/private/backups/${private}"
  fi

  log "You have chosen to restore backup file '$file'"
  if [ -f "$file" ]; then
      RESTORE_ARGS=
      if [ -f "$public" ]; then
        log "Public files backup will also be restored: '$public'"
        RESTORE_ARGS="${RESTORE_ARGS} --with-public-files $public"
      elif [ -n "$public" ]; then
        log "Requested public files backup '$public' was not found!"
      fi
      if [ -f "$private" ]; then
        log "Private files backup will also be restored: '$private'"
        RESTORE_ARGS="${RESTORE_ARGS} --with-private-files $private"
      elif [ -n "$private" ]; then
        log "Requested private files backup '$private' was not found!"
      fi

      bench --force restore ${RESTORE_ARGS} "$file" \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"

    log "Backup successfully restored."
    # Call bench doctor after backup
    bench_doctor
  else
    log "Requested backup was not found!"
    exit 1
  fi
}

bench_setup_requirements() {
  setup_logs_owner
  log "Starting setup of requirements..."
  bench setup requirements $@ \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
  log "Requirements setup Finished"
}

bench_migrate() {
  setup_logs_owner
  log "Starting migration..."
  bench migrate $@ \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
  log "Migrate Finished"

  # Call bench doctor after migrate
  bench_doctor
}


# -------------------------------------------------------------------
# Frappe Bench service functions

bench_app() {
  bench_doctor

  log "Starting app on port ${DOCKER_GUNICORN_PORT}..."
  cd "${FRAPPE_WD}/sites"

  GUNICORN_ARGS="-t ${DOCKER_GUNICORN_TIMEOUT} --workers ${DOCKER_GUNICORN_WORKERS} --bind ${DOCKER_GUNICORN_BIND_ADDRESS}:${DOCKER_GUNICORN_PORT} --log-level ${DOCKER_GUNICORN_LOGLEVEL}"

  if [ -n "${DOCKER_GUNICORN_CERTFILE}" ]; then
    GUNICORN_ARGS="${DOCKER_GUNICORN_ARGS} --certfile=${DOCKER_GUNICORN_CERTFILE}"
  fi

  if [ -n "${DOCKER_GUNICORN_KEYFILE}" ]; then
    GUNICORN_ARGS="${DOCKER_GUNICORN_ARGS} --keyfile=${DOCKER_GUNICORN_KEYFILE}"
  fi

  "${FRAPPE_WD}/env/bin/gunicorn" \
    $GUNICORN_ARGS \
    frappe.app:application --preload \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_scheduler() {
  log "Starting scheduler..."
  bench schedule \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_worker() {
  log "Starting $1 worker..."
  bench worker --queue "$1" \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}

bench_socketio() {
  log "Starting socketio..."
  node "${FRAPPE_WD}/apps/frappe/socketio.js" \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.log" 3>&1 1>&2 2>&3 \
    | sudo tee "${FRAPPE_WD}/logs/${NODE_TYPE}.err.log"
}


# -------------------------------------------------------------------
# Runtime

reset_logs
setup_logs_owner

if [ -f "/before_${NODE_TYPE}_init.sh" ]; then
  log "Executin custom script before '${NODE_TYPE}' init..."
  "/before_${NODE_TYPE}_init.sh"
fi

if [[ "${FRAPPE_RESET_SITES}" == "1" ]]; then
  log "Removing all sites!"
  rm -rf "${FRAPPE_WD}/sites/*"
fi


# Frappe automatic app init
if [ -n "${FRAPPE_APP_INIT}" ]; then

  setup_sites_owner

  # Remove anything from apps.txt which is not in requested through docker
  if [ -f "${FRAPPE_WD}/sites/apps.txt" ]; then
    log "Checking bench apps to remove before init..."

    for app in $(cat ${FRAPPE_WD}/sites/apps.txt); do
      if ! echo "${FRAPPE_APP_PROTECTED}" | grep -qE "(^| )${app}( |$)" && ! echo "${FRAPPE_APP_INIT}" | grep -qE "(^| )${app}( |$)"; then
        log "Removing '$app' from bench..."
        bench remove-from-installed-apps "$app" \
          | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
          | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
      fi
    done
  fi

  # Reset apps
  if [ ! -f "${FRAPPE_WD}/sites/apps.txt" ] || [[ "${FRAPPE_APP_RESET}" == "1" ]]; then
    log "Adding frappe to apps.txt..."
    sudo touch "${FRAPPE_WD}/sites/apps.txt"
    sudo chown "${FRAPPE_USER}:${FRAPPE_USER}" \
      "${FRAPPE_WD}/sites/apps.txt" \
    ;
    echo "frappe" > "${FRAPPE_WD}/sites/apps.txt"
  fi

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
  "allow_tests": ${ALLOW_TESTS:-0},
  "server_script_enabled": ${SERVER_SCRIPT_ENABLED:-0},
  "deny_multiple_logins": false,
  "disable_website_cache": false,
  "dns_multitenant": false,
  "serve_default_site": true,
  "frappe_user": "${FRAPPE_USER}",
  "auto_update": false,
  "update_bench_on_update": true,
  "shallow_clone": true,
  "rebase_on_pull": false,
  "redis_cache": "redis://${REDIS_CACHE_HOST}",
  "redis_queue": "redis://${REDIS_QUEUE_HOST}",
  "redis_socketio": "redis://${REDIS_SOCKETIO_HOST}",
  "logging": "${FRAPPE_LOGGING:-1}",
  "root_login": "${DB_ROOT_LOGIN}",
  "root_password": "${DB_ROOT_PASSWORD}",
  "db_type": "${DB_TYPE}",
  "db_host": "${DB_HOST}",
  "db_port": ${DB_PORT},
  "db_name": "${DB_NAME}",
  "db_user": "${DB_NAME}",
  "db_password": "${DB_PASSWORD}",
  "host_name": "${FRAPPE_DEFAULT_PROTOCOL:-http}://${FRAPPE_DEFAULT_SITE}:${FRAPPE_HTTP_PORT:-80}",
  "http_port": ${FRAPPE_HTTP_PORT:-80},
  "webserver_port": ${FRAPPE_WEBSERVER_PORT:-80},
  "socketio_port": ${FRAPPE_SOCKETIO_PORT:-3000},
  "google_analytics_id": "${GOOGLE_ANALYTICS_ID}",
  "developer_mode": ${DEVELOPER_MODE:-0},
  "admin_password": "${ADMIN_PASSWORD:-admin}",
  "encryption_key": "${ENCRYPTION_KEY:-$(openssl rand -base64 32)}",
  "mail_server": "${MAIL_HOST}",
  "mail_port": ${MAIL_PORT},
  "use_ssl": "${MAIL_USE_SSL}",
  "mail_login": "${MAIL_LOGIN}",
  "mail_password": "${MAIL_PASSWORD}",
  "auto_email_id": "${MAIL_EMAIL_ID}",
  "email_sender_name": "${MAIL_SENDER_NAME}",
  "always_use_account_email_id_as_sender": ${MAIL_ALWAYS_EMAIL_ID_AS_SENDER:-0},
  "always_use_account_name_as_sender_name": ${MAIL_ALWAYS_NAME_AS_SENDER_NAME:-0},
  "mute_emails": ${MAIL_MUTED:-1}
}
EOF
  fi

  # Check default site config
  if [ ! -f "${FRAPPE_WD}/sites/${FRAPPE_DEFAULT_SITE}/site_config.json" ]; then
    # TODO Not really clean to copy common config to site... better to create specific properties
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
        --mariadb-root-password "${DB_ROOT_PASSWORD}" \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
    else
      bench new-site "${FRAPPE_DEFAULT_SITE}" \
        --force \
        --db-name ${DB_NAME} \
        --admin-password ${ADMIN_PASSWORD} \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"
    fi

    log "Setting ${FRAPPE_DEFAULT_SITE} as current site..."
    sudo touch "${FRAPPE_WD}/sites/currentsite.txt"
    sudo chown "${FRAPPE_USER}:${FRAPPE_USER}" \
      "${FRAPPE_WD}/sites/currentsite.txt" \
    ;
    echo "${FRAPPE_DEFAULT_SITE}" > "${FRAPPE_WD}/sites/currentsite.txt"
  fi

  log "Using site at ${FRAPPE_DEFAULT_SITE}..."
  bench use "${FRAPPE_DEFAULT_SITE}" \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | sudo tee -a "${FRAPPE_WD}/logs/${NODE_TYPE}-docker.err.log"

  echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-site-init"
  log "Docker Frappe automatic site setup ended"
else
  # Wait for another node to setup sites
  wait_sites
fi



if [ -n "${FRAPPE_APP_INIT}" ]; then

  # Frappe automatic app setup
  if [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ] || [[ "${FRAPPE_REINSTALL_DATABASE}" == "1" ]]; then

    # Call bench setup for app
    log "Docker Frappe automatic app setup..."
    bench_setup "${FRAPPE_APP_INIT}"

    echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-app-init"
    log "Docker Frappe automatic app setup ended"

  else

    # Add any missing app to init in apps.txt
    log "Docker Frappe automatic app update..."
    bench_install_apps "${FRAPPE_APP_INIT}"

    echo "$(date +%Y-%m-%dT%H:%M:%S%:z)" > "${FRAPPE_WD}/sites/.docker-app-init"
    log "Docker Frappe automatic app update ended"

  fi

  # Frappe automatic app migration (based on container build properties)
  if [ -f "${FRAPPE_WD}/sites/.docker-init" ] && ! grep -q "${DOCKER_TAG} ${DOCKER_VCS_REF} ${DOCKER_BUILD_DATE}" "${FRAPPE_WD}/sites/.docker-init"; then
    bench_setup_requirements
    bench_build_apps
    bench_migrate
  fi
  echo "${DOCKER_TAG} ${DOCKER_VCS_REF} ${DOCKER_BUILD_DATE}" > "${FRAPPE_WD}/sites/.docker-init"

fi

if [ -f "/after_${NODE_TYPE}_init.sh" ]; then
  log "Executin custom script after '${NODE_TYPE}' init..."
  "/after_${NODE_TYPE}_init.sh"
fi



# Execute task based on node type
case "${NODE_TYPE}" in
  # Management tasks
  ("doctor") wait_db; bench_doctor ;;
  ("setup") pip_install; shift; bench_setup $@ ;;
  ("setup-database") bench_setup_database ;;
  ("install-apps") bench_install_apps ;;
  ("build-apps") pip_install; bench_build_apps ;;
  ("update") shift; bench_update $@ ;;
  ("backup") shift; bench_backup $@ ;;
  ("restore") shift; bench_restore $@ ;;
  ("migrate") shift; bench_migrate $@ ;;
  # Service tasks
  ("app") wait_db; pip_install; bench_app ;;
  ("scheduler") bench_scheduler ;;
  ("worker-default") bench_worker default ;;
  ("worker-long") bench_worker long ;;
  ("worker-short") bench_worker short ;;
  ("node-socketio") bench_socketio ;;
  # TODO Add a cron task ?
  (*) exec "$@" ;;
esac
