FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="Source Dedicated Server"
LABEL org.opencontainers.image.description="Minimal Source-engine runtime for Pterodactyl"
LABEL org.opencontainers.image.source="https://github.com/refoseldev/yolks"
LABEL org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        iproute2 \
        lib32gcc-s1 \
        lib32stdc++6 \
        libcurl4:i386 \
        libfontconfig1 \
        libgcc-s1:i386 \
        libncurses6:i386 \
        locales \
        libsdl2-2.0-0:i386 \
        libssl3:i386 \
        libtinfo6:i386 \
        netcat-openbsd \
        tar \
        tzdata \
    && sed -i \
        -e 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
        -e 's/^# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' \
        /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /home/container --shell /bin/bash container

USER container
ENV USER=container \
    HOME=/home/container \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8
WORKDIR /home/container

COPY --chown=container:container entrypoint.sh /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]
