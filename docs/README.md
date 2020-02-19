# Monogramm Docker Frappe documentation

:construction: **Add sample usage of this image.**


## Known issues

A list of a few issues encountered during the development of this container for future reference:
* Frappe 10 references croniter==0.3.26 which does not exist
    * _Solution_: Update requirements.txt croniter==0.3.26 to croniter==0.3.29
    * _References_:
        * https://discuss.erpnext.com/t/easy-install-for-v10-no-longer-works-fails-every-time-w-same-error-multiple-os/47899/24
* ModuleNotFoundError: No module named 'pip.req' with pip 10 and bench 4
    * _Solution_: Downgrade pip to 9.3
    * _References_:
        * https://discuss.erpnext.com/t/bench-install-on-easy-setup-failing-no-pip-req/35823/11
* Error: Cannot find module 'rollup'
    * _Solution_: Use appropriate Python version (2 for 10, 3 for 11)
    * _References_:
        * https://discuss.erpnext.com/t/error-cannot-find-module-rollup/45204
        * https://discuss.erpnext.com/t/cannot-find-module-rollup/48989
* Error: Cannot find module 'chalk'
    * _Solution_: setup socketio and requirements
    * _References_:
        * https://discuss.erpnext.com/t/error-cannot-find-module-chalk/44851
        * https://discuss.erpnext.com/t/error-while-installing-frappe-on-my-ubuntu-16-04-server/37417/3
* Error during `bench init frappe-bench`due to missing node modules:
    * _Solution_: install modules manually and call `bench setup requirements`
    * _References_:
        * https://discuss.erpnext.com/t/error-while-installing-frappe-on-my-ubuntu-16-04-server/37417/4
        * https://discuss.erpnext.com/t/error-on-bench-build/41467
* Could not find a version that satisfies the requirement croniter==0.3.26:
    * _Solution_: switch to branch v10.x.x for latest bugfixes
    * _References_:
        * https://discuss.erpnext.com/t/easy-install-for-v10-no-longer-works-fails-every-time-w-same-error-multiple-os/47899/14
        * https://github.com/frappe/frappe/pull/7286
* New site fails while migrating the DocType: DocField with postgres database:
    * _Solution_: none so far...
    * _References_:
        * https://github.com/frappe/frappe/issues/8093
