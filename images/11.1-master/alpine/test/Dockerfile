# For development or CI, build from local Dockerfile
FROM docker-frappe:11-alpine
# For production, download prebuilt image
#FROM monogramm/docker-frappe:11

ADD docker_test.sh /docker_test.sh

RUN set -ex; \
    sudo chmod 755 /docker_test.sh;

CMD ["/docker_test.sh"]
