
[uri_license]: http://www.gnu.org/licenses/agpl.html
[uri_license_image]: https://img.shields.io/badge/License-AGPL%20v3-blue.svg

[![License: AGPL v3][uri_license_image]][uri_license]
[![Build Status](https://travis-ci.org/Monogramm/docker-frappe.svg)](https://travis-ci.org/Monogramm/docker-frappe)
[![Docker Automated buid](https://img.shields.io/docker/cloud/build/monogramm/docker-frappe.svg)](https://hub.docker.com/r/monogramm/docker-frappe/)
[![Docker Pulls](https://img.shields.io/docker/pulls/monogramm/docker-frappe.svg)](https://hub.docker.com/r/monogramm/docker-frappe/)
[![](https://images.microbadger.com/badges/version/monogramm/docker-frappe.svg)](https://microbadger.com/images/monogramm/docker-frappe)
[![](https://images.microbadger.com/badges/image/monogramm/docker-frappe.svg)](https://microbadger.com/images/monogramm/docker-frappe)

# Frappe custom Docker container

Docker image for Frappe applications.

This image is directly inspired by [BizzoTech/docker-frappe](https://github.com/BizzoTech/docker-frappe) but derived adds an alpine variation, like provided by [donysukardi/docker-frappe](https://github.com/donysukardi/docker-frappe).

:construction: **This image is still in development!**

## What is Frappe ?

Full-stack web application framework that uses Python and MariaDB on the server side and a tightly integrated client side library. Built for [ERPNext](https://erpnext.com/).

> [frappe.io](https://frappe.io/)

> [github frappe](https://github.com/frappe/frappe)

## Supported tags

https://hub.docker.com/r/monogramm/docker-frappe/

* frappe 11.1
    - `11.1-alpine` `11.1` `alpine` `latest`
    - `11.1-stretch` `stretch`
    - `11.1-stretch-slim` `stretch-slim`
* frappe 10.1
    - `10.1-alpine` `10.1`
    - `10.1-stretch`
    - `10.1-stretch-slim`

# Questions / Issues
If you got any questions or problems using the image, please visit our [Github Repository](https://github.com/Monogramm/docker-frappe) and write an issue.  

# References

A list of a few issues encountered during the development of this container for future reference:
* Frappe 10 references croniter==0.3.26 which does not exist
    * _Solution_: Update requirements.txt croniter==0.3.26 to croniter==0.3.29
    * _References_:
        * https://discuss.erpnext.com/t/easy-install-for-v10-no-longer-works-fails-every-time-w-same-error-multiple-os/47899/24
* ModuleNotFoundError: No module named 'pip.req' with pip 10 and bench 4.1
    * _Solution_: Downgrade pip to 9.3
    * _References_:
        * https://discuss.erpnext.com/t/bench-install-on-easy-setup-failing-no-pip-req/35823/11
* Error: Cannot find module 'rollup'
    * _Solution_: Use appropriate Python version (2 for 10.1, 3  for 11.1)
    * _References_:
        * https://discuss.erpnext.com/t/error-cannot-find-module-rollup/45204
        * https://discuss.erpnext.com/t/cannot-find-module-rollup/48989
