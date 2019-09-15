# For development or CI, build from local Dockerfile
FROM docker-frappe:%%FRAPPE_VERSION%%-%%VARIANT%%
# For production, download prebuilt image
#FROM monogramm/docker-frappe:%%FRAPPE_VERSION%%

ADD docker_test.sh /docker_test.sh

RUN set -ex; \
    test "%%VARIANT%%" == "debian-slim" && apt-get update && apt-get install ping; \
    sudo chmod 755 /docker_test.sh;

CMD ["/docker_test.sh"]
