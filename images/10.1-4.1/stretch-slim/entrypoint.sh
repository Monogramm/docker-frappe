#!/bin/sh

NODE_TYPE=${1}
APP=${2}
DB_HOST=${DB_HOST:=db}
DB_PORT=${DB_HOST:=3306}

bench use localhost

cd /home/$FRAPPE_USER/frappe-bench
ls apps/ | while read -r file; do  if [ $file != "frappe" ]; then ./env/bin/pip install -q -e apps/$file --no-cache-dir; fi; done && \


echo 'Waiting for DB to start up'

dockerize -wait "tcp://${DB_HOST}:${DB_PORT}" -timeout 120s


# TASK=$(case "$NODE_TYPE" in
#   ("app") echo "/home/$FRAPPE_USER/frappe-bench/env/bin/gunicorn -b 0.0.0.0:8000 -w 4 -t 120 frappe.app:application --preload" ;;
#   ("setup") echo "echo \"Setup Finished \" " ;;
#   ("setup-apps") echo "echo \"Setup Finished \" " ;;
#   ("update") echo "/usr/bin/bench update --no-git" ;;
#   ("backup") echo "/usr/bin/bench backup && echo \"Backup Finished \" " ;;
#   ("restore") echo "echo \"Restore Finished \" " ;;
#   ("migrate") echo "/usr/bin/bench migrate" ;;
#   ("scheduler") echo "/usr/bin/bench schedule" ;;
#   ("worker-default") echo "/usr/bin/bench worker --queue default" ;;
#   ("worker-long") echo "/usr/bin/bench worker --queue long" ;;
#   ("worker-short") echo "/usr/bin/bench worker --queue short" ;;
#   ("node-socketio") echo "node /home/$FRAPPE_USER/frappe-bench/apps/frappe/socketio.js" ;;
#   (*) ;;
# esac)

if [ ${NODE_TYPE} = "app" ]; then
  echo "Starting app..."
  cd /home/$FRAPPE_USER/frappe-bench/sites
  /home/$FRAPPE_USER/frappe-bench/env/bin/gunicorn -b 0.0.0.0:8000 -w 4 -t 120 frappe.app:application --preload
fi;

if [ ${NODE_TYPE} = "update" ]; then
  bench update --no-git
  echo "Update Finished"
fi;

if [ ${NODE_TYPE} = "setup" ]; then
  bench reinstall --yes && bench install-app $APP && \
  ls apps/ | while read -r file; do  if [ $file != "frappe" ]; then bench install-app $file; fi; done
  echo "$APP Setup Finished"
fi;

if [ ${NODE_TYPE} = "setup-apps" ]; then
  ls apps/ | while read -r file; do  if [ $file != "frappe" ]; then bench install-app $file; fi; done
  echo "Setup Finished"
fi;

if [ ${NODE_TYPE} = "migrate" ]; then
  bench migrate
  echo "Migrate Finished"
fi;

if [ ${NODE_TYPE} = "backup" ]; then
  bench backup
  echo "Backup Finished"
fi;

if [ ${NODE_TYPE} = "restore" ]; then
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
fi;

if [ ${NODE_TYPE} = "scheduler" ]; then
  echo "Starting scheduler..."
  bench schedule
fi;

if [ ${NODE_TYPE} = "worker-default" ]; then
  echo "Starting default worker..."
  bench worker --queue default
fi;

if [ ${NODE_TYPE} = "worker-long" ]; then
  echo "Starting long worker..."
  bench worker --queue long
fi;

if [ ${NODE_TYPE} = "worker-short" ]; then
  echo "Starting short worker..."
  bench worker --queue short
fi;

if [ ${NODE_TYPE} = "node-socketio" ]; then
  echo "Starting socketio..."
  node /home/$FRAPPE_USER/frappe-bench/apps/frappe/socketio.js
fi;

# (eval $TASK | tee /home/$FRAPPE_USER/frappe-bench/logs/${NODE_TYPE}.log) 3>&1 1>&2 2>&3 | tee /home/$FRAPPE_USER/frappe-bench/logs/${NODE_TYPE}.err.log
