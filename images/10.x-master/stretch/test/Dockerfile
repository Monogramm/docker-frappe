# For development or CI, build from local Dockerfile
FROM docker-frappe:10-stretch
# For production, download prebuilt image
#FROM monogramm/docker-frappe:10

ADD docker_test.sh /docker_test.sh

RUN set -ex; \
    test 'stretch' == 'stretch-slim' && apt-get update && apt-get install iputils-ping; \
    sudo chmod 755 /docker_test.sh;

CMD ["/docker_test.sh"]
