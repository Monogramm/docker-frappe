# For development or CI, build from local Dockerfile (.travis.yml will update base before tests)
# For production, download prebuilt image
FROM monogramm/docker-frappe:%%FRAPPE_VERSION%%-%%VARIANT%%

COPY docker_test.sh /docker_test.sh

USER root

RUN set -ex; \
    test '%%VARIANT%%' = 'debian-slim' && apt-get update && apt-get install -y --allow-unauthenticated iputils-ping; \
    chmod 755 /docker_test.sh; \
    pip install coverage==4.5.4; \
    pip install python-coveralls

USER $FRAPPE_USER

# TODO QUnit (JS) Unit tests
EXPOSE 4444

# Default Chrome configuration
ENV DISPLAY=:20.0 \
    SCREEN_GEOMETRY="1440x900x24" \
    CHROMEDRIVER_PORT=4444 \
    CHROMEDRIVER_WHITELISTED_IPS="127.0.0.1" \
    CHROMEDRIVER_URL_BASE='' \
    CHROMEDRIVER_EXTRA_ARGS=''

CMD ["/docker_test.sh"]
