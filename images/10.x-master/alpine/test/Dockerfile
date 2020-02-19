# For development or CI, build from local Dockerfile
# For production, download prebuilt image
FROM docker-frappe:10-alpine

ADD docker_test.sh /docker_test.sh

RUN set -ex; \
    test 'alpine' = 'debian-slim' && sudo apt-get update && sudo apt-get install -y --allow-unauthenticated iputils-ping; \
    sudo chmod 755 /docker_test.sh;

CMD ["/docker_test.sh"]
