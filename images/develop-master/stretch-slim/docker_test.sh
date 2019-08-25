#!/usr/bin/sh

if [ ! -f "${FRAPPE_WD}/sites/apps.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]; then
    echo 'Apps were not installed in time!'
    exit -1
fi

if [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ] || [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]; then
    echo 'Site was not installed in time!'
    exit -2
fi

if [ ! sudo ping -c 10 -q frappe_db ]; then
    echo 'Frappe database container is not responding!'
    exit -4
fi

if [ ! sudo ping -c 10 -q frappe_app ]; then
    echo 'Frappe app container is not responding!'
    exit -8
fi

if [ ! sudo ping -c 10 -q frappe_web ]; then
    echo 'Frappe web container is not responding!'
    exit -16
fi

# Success
echo 'Frappe docker test successful'
exit 0
