ARG VERSION=3.3.2
ARG JRE=21
ARG UID=200020
ARG GID=200020

FROM alpine:latest AS fetch_tika

ARG VERSION
ARG JRE
ARG CHECK_SIG=true

ENV TIKA_VERSION=${VERSION}

ENV TIKA_SERVER_ARCHIVE="tika-server-standard-${TIKA_VERSION}.zip" \
    NEAREST_TIKA_SERVER_URL="https://dlcdn.apache.org/tika/${TIKA_VERSION}/tika-server-standard-${TIKA_VERSION}.jar" \
    ARCHIVE_TIKA_SERVER_URL="https://archive.apache.org/dist/tika/${TIKA_VERSION}/tika-server-standard-${TIKA_VERSION}.jar" \
    BACKUP_TIKA_SERVER_URL="https://downloads.apache.org/tika/${TIKA_VERSION}/tika-server-standard-${TIKA_VERSION}.jar" \
    DEFAULT_TIKA_SERVER_ASC_URL="https://downloads.apache.org/tika/${TIKA_VERSION}/tika-server-standard-${TIKA_VERSION}.jar.asc" \
    ARCHIVE_TIKA_SERVER_ASC_URL="https://archive.apache.org/dist/tika/${TIKA_VERSION}/tika-server-standard-${TIKA_VERSION}.jar.asc"

RUN apk -U upgrade \
    && apk add gnupg openjdk${JRE}-jre wget \
    && rm -rf /var/cache/apk/* \
    && wget -t 10 --max-redirect 1 --retry-connrefused -qO- https://downloads.apache.org/tika/KEYS | gpg --import \
    && wget -t 10 --max-redirect 1 --retry-connrefused $NEAREST_TIKA_SERVER_URL -O /${TIKA_SERVER_ARCHIVE} || rm /${TIKA_SERVER_ARCHIVE} \
    && sh -c "[ -f /${TIKA_SERVER_ARCHIVE} ]" || wget $ARCHIVE_TIKA_SERVER_URL -O /${TIKA_SERVER_ARCHIVE} || rm /${TIKA_SERVER_ARCHIVE} \
    && sh -c "[ -f /${TIKA_SERVER_ARCHIVE} ]" || wget $BACKUP_TIKA_SERVER_URL -O /${TIKA_SERVER_ARCHIVE} || rm /${TIKA_SERVER_ARCHIVE} \
    && sh -c "[ -f /${TIKA_SERVER_ARCHIVE} ]" || exit 1 \
    && wget -t 10 --max-redirect 1 --retry-connrefused $DEFAULT_TIKA_SERVER_ASC_URL -O /${TIKA_SERVER_ARCHIVE}.asc || rm /${TIKA_SERVER_ARCHIVE}.asc \
    && sh -c "[ -f /${TIKA_SERVER_ARCHIVE}.asc ]" || wget $ARCHIVE_TIKA_SERVER_ASC_URL -O /${TIKA_SERVER_ARCHIVE}.asc || rm /${TIKA_SERVER_ARCHIVE}.asc \
    && sh -c "[ -f /${TIKA_SERVER_ARCHIVE}.asc ]" || exit 1 \
    && gpg --verify /${TIKA_SERVER_ARCHIVE}.asc /${TIKA_SERVER_ARCHIVE} \
    && mkdir -p /opt/tika-server \
    && unzip -q /${TIKA_SERVER_ARCHIVE} -d /opt/tika-server \
    && rm /${TIKA_SERVER_ARCHIVE} /${TIKA_SERVER_ARCHIVE}.asc

FROM alpine:latest

ARG VERSION
ARG JRE
ARG UID
ARG GID

ENV TIKA_VERSION=${VERSION}

RUN apk -U upgrade \
    && apk add ca-certificates libstdc++ openjdk${JRE}-jre \
    && rm -rf /var/cache/apk/*

RUN --network=none \
    addgroup -g ${GID} tika \
    && adduser -u ${UID} --ingroup tika --disabled-password --system tika

COPY --from=fetch_tika /opt/tika-server /opt/tika-server
WORKDIR /opt/tika-server

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

USER tika
EXPOSE 9998

ENTRYPOINT [ "/bin/sh", "-c", "exec java -cp \"/opt/tika-server/*:/opt/tika-server/lib/*:/tika-extras/*\" org.apache.tika.server.core.TikaServerCli -h 0.0.0.0 $0 $@"]
