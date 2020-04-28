[uri_license]: http://www.gnu.org/licenses/agpl.html

[uri_license_image]: https://img.shields.io/badge/License-AGPL%20v3-blue.svg

[![License: AGPL v3][uri_license_image]][uri_license]
[![Build Status](https://travis-ci.org/Monogramm/docker-frappe.svg)](https://travis-ci.org/Monogramm/docker-frappe)
[![Docker Automated buid](https://img.shields.io/docker/cloud/build/monogramm/docker-frappe.svg)](https://hub.docker.com/r/monogramm/docker-frappe/)
[![Docker Pulls](https://img.shields.io/docker/pulls/monogramm/docker-frappe.svg)](https://hub.docker.com/r/monogramm/docker-frappe/)
[![](https://images.microbadger.com/badges/version/monogramm/docker-frappe.svg)](https://microbadger.com/images/monogramm/docker-frappe)
[![](https://images.microbadger.com/badges/image/monogramm/docker-frappe.svg)](https://microbadger.com/images/monogramm/docker-frappe)

# Frappe custom Docker container

:whale: Docker image for Frappe applications.

This image was inspired by several other containers developed by the community:

-   [emadshaaban92/docker-compose-erpnext](https://github.com/emadshaaban92/docker-compose-erpnext/) / [BizzoTech/docker-frappe](https://github.com/BizzoTech/docker-frappe) for the "_simple_" docker-compose setup
-   [donysukardi/docker-frappe](https://github.com/donysukardi/docker-frappe) for the alpine variant (actually the source for BizzoTech images)
-   [pipech/erpnext-docker-debian](https://github.com/pipech/erpnext-docker-debian) for the complete setup of apps and sites
-   [madnight/docker-alpine-wkhtmltopdf](https://github.com/madnight/docker-alpine-wkhtmltopdf)

The concept is the following:

-   no need to provide any configuration file: everything will be automatically generated by the container through environnment variables
-   the application container sets all the environment variables, the other containers wait for setup to be done
-   provide postgresql compatibility
-   the container detects and execute migration automatically
-   the container detects missing modules / apps and remove them automatically
-   allow before and after '_node_' custom scripts

Check image [Monogramm/docker-erpnext](https://github.com/Monogramm/docker-erpnext) to see how to expand this image and build frappe apps.

## What is Frappe ?

Full-stack web application framework that uses Python and MariaDB on the server side and a tightly integrated client side library. Built for [ERPNext](https://erpnext.com/).

> [frappe.io](https://frappe.io/)

> [github frappe](https://github.com/frappe/frappe)

## Supported tags

<https://hub.docker.com/r/monogramm/docker-frappe/>

-   Frappe develop branch
    -   `develop-alpine` `develop`
    -   `develop-debian`
    -   `develop-debian-slim`
-   Frappe 12
    -   `12-alpine` `12` `alpine` `latest`
    -   `12-debian` `debian`
    -   `12-debian-slim` `debian-slim`
-   Frappe 11
    -   `11-alpine` `11`
    -   `11-debian`
    -   `11-debian-slim`
-   Frappe 10 (branch 10.x.x for latest bug fixes)
    -   `10-alpine` `10`
    -   `10-debian`
    -   `10-debian-slim`

# Auto configuration via environment variables

The image supports auto configuration via environment variables.

## Docker entrypoint configuration

```sh
# The docker "node" type. Defines the behavior of the container.
# This can either be set through command argument or environment variable.
# Can be one of the following:
#   doctor
#   setup
#   setup-database
#   build-apps
#   update
#   backup
#   restore
#   migrate
#   app
#   scheduler
#   worker-default
#   worker-long
#   worker-short
#   node-socketio
NODE_TYPE=

# Time in seconds container will wait for DB to be up
DOCKER_DB_TIMEOUT=120

# MariaDb hosts allowed to log to the DB.
# Only needed with mariadb when database created by frappe (frappe restricts to install IP by default).
# In this case, use 172.%.%.% to allow any container on docker network
DOCKER_DB_ALLOWED_HOSTS=

# Time in seconds container will wait for apps to be setup
DOCKER_APPS_TIMEOUT=600

# Time in seconds container will wait for sites to be setup
DOCKER_SITES_TIMEOUT=900

# Set to 1 to enable display of all log files if container crashes
DOCKER_DEBUG=

DOCKER_GUNICORN_BIND_ADDRESS=0.0.0.0
DOCKER_GUNICORN_PORT=8000
DOCKER_GUNICORN_WORKERS=4
DOCKER_GUNICORN_TIMEOUT=120
DOCKER_GUNICORN_LOGLEVEL=info

# If you want to enable SSL for ERPNext App
# If using Let's Encrypt, you should set properties like this:
#   certfile=/etc/letsencrypt/live/my.domain.com/fullchain.pem
#   keyfile=/etc/letsencrypt/live/my.domain.com/privkey.pem
DOCKER_GUNICORN_CERTFILE=
DOCKER_GUNICORN_KEYFILE=
```

## Frappe configuration

```sh
# List of frappe apps (space separated) to init on startup (bench install-app)
FRAPPE_APP_INIT=

# Reset apps.txt
# If set to 1, apps.txt older content will be removed on startup and only contain the content of FRAPPE_APP_INIT
FRAPPE_APP_RESET=

# Protected apps that shall never be removed automatically
# Mostly used to secure that frappe and erpnext are not removed due to misconfiguration
FRAPPE_APP_PROTECTED=frappe

# Default protocol. Should either be http (default value) or https when using SSL.
FRAPPE_DEFAULT_PROTOCOL=http

# Default site
FRAPPE_DEFAULT_SITE=

# Default HTTP port. Should either be 80 (default value) or 443 when using SSL or any custom port defined for the NGinx reverse proxy.
FRAPPE_HTTP_PORT=80

# Default backend port. Should either be 80 (default value) or any custom port defined for the app backend.
FRAPPE_WEBSERVER_PORT=80

# Default socketion port. Should either be 3000 (default value) or 80 (usual value for prod) or any custom port defined for the socketio service.
FRAPPE_SOCKETIO_PORT=3000

# Remove all sites data on startup if set to 1
# This should only be used for dev / test environments
FRAPPE_RESET_SITES=

# Reinstall database
# If set to 1, database will be resinstalled. This should only be used for dev / test environments
FRAPPE_REINSTALL_DATABASE=

# Build options passed to the bench build command
# Can be used with --restore to copy the public assets instead of symlinking them
FRAPPE_BUILD_OPTIONS=

FRAPPE_LOGGING=1

GOOGLE_ANALYTICS_ID=

DEVELOPER_MODE=0
ALLOW_TESTS=0
SERVER_SCRIPT_ENABLED=0

ADMIN_PASSWORD=frappe

# Encryption key
# Leave empty to generate a random base64 32 key
ENCRYPTION_KEY=
```

## Database configuration

```sh
# DB type. Can either be mariadb or postgresql
DB_TYPE=mariadb

DB_HOST=db
DB_PORT=3306

# DB name. Is also used by frappe for the user name associated
DB_NAME=frappe
DB_PASSWORD=youshouldoverwritethis

# DB root login. Only used for postgresql
DB_ROOT_LOGIN=root

# DB root password. Mandatory
DB_ROOT_PASSWORD=mariadb_root_password
```

## Mail configuration

```sh
MAIL_MUTED=false
MAIL_HOST=mail
MAIL_PORT=587
MAIL_USE_SSL=tls
MAIL_LOGIN=frappe-mail
MAIL_PASSWORD=youshouldoverwritethis
```

## Redis configuration

```sh
REDIS_CACHE_HOST=redis_cache
REDIS_QUEUE_HOST=redis_queue
REDIS_SOCKETIO_HOST=redis_socketio
```

## How to run this image ?

This image does not contain the database for Frappe. You need to use either an existing database or a database container.

This image is designed to be used in a micro-service environment using docker-compose. There are basically 2 variants of the image you can choose from: `alpine` or `debian`.

# Running this image with docker-compose

-   Select the version closest to what you want in the images folder
    -   You can comment the `build` lines, uncomment the `image` lines and edit versions to download prebuilt docker container.
-   Feel free to edit variables defined in `.env` as you see fit.
-   Run the docker-compose with `docker-compose up -d` and that's it.
-   Now, go to <http://localhost:80> to access the first run installation wizard.

# Questions / Issues

If you got any questions or problems using the image, please visit our [Github Repository](https://github.com/Monogramm/docker-frappe) and write an issue.

# Documentation

Additional documentation can be found [here](docs/README.md).
