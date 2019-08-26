#!/usr/bin/sh

echo "Waiting to ensure everything is fully ready for the tests..."
sleep 60

echo "Checking content of sites directory..."
if [ ! -f "${FRAPPE_WD}/sites/apps.txt" ]
    || [ ! -f "${FRAPPE_WD}/sites/.docker-app-init" ]
    || [ ! -f "${FRAPPE_WD}/sites/currentsite.txt" ]
    || [ ! -f "${FRAPPE_WD}/sites/.docker-site-init" ]
    || [ ! -f "${FRAPPE_WD}/sites/.docker-init" ]; then
    echo 'Apps and site are not initalized!'
    exit 1
fi

echo "Checking main containers are reachable..."
if [ ! sudo ping -c 10 -q frappe_db ]; then
    echo 'Frappe database container is not responding!'
    exit 4
fi

if [ ! sudo ping -c 10 -q frappe_app ]; then
    echo 'Frappe app container is not responding!'
    exit 8
fi

if [ ! sudo ping -c 10 -q frappe_web ]; then
    echo 'Frappe web container is not responding!'
    exit 16
fi

# Success
echo 'Frappe docker test successful'
exit 0
