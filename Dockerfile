FROM alpine:latest AS subconverter_bins
ARG THREADS="20"
ARG SHA=""

# build minimized
WORKDIR /

COPY 0001-regGetMatch-Proxy-doesnt-work-for-Glados-yaml.patch /
#COPY 0002-Modified-Version.patch /
COPY 0003-Default-Loglevel-INFO.patch /
COPY 0004-Default-Loglevel-INFO-in-toml.patch /

RUN set -xe && \
    apk add --no-cache --virtual .build-tools git g++ build-base linux-headers cmake python3 py3-pip py3-gitpython && \
    apk add --no-cache --virtual .build-deps curl-dev rapidjson-dev pcre2-dev yaml-cpp-dev && \
    git clone https://github.com/ftk/quickjspp --depth=1 && \
    cd quickjspp && \
    git submodule update --init && \
    cmake -DCMAKE_BUILD_TYPE=Release . && \
    make quickjs -j $THREADS && \
    install -d /usr/lib/quickjs/ && \
    install -m644 quickjs/libquickjs.a /usr/lib/quickjs/ && \
    install -d /usr/include/quickjs/ && \
    install -m644 quickjs/quickjs.h quickjs/quickjs-libc.h /usr/include/quickjs/ && \
    install -m644 quickjspp.hpp /usr/include && \
    cd .. && \
    git clone https://github.com/PerMalmberg/libcron --depth=1 && \
    cd libcron && \
    git submodule update --init && \
    cmake -DCMAKE_BUILD_TYPE=Release . && \
    make libcron -j $THREADS && \
    install -m644 libcron/out/Release/liblibcron.a /usr/lib/ && \
    install -d /usr/include/libcron/ && \
    install -m644 libcron/include/libcron/* /usr/include/libcron/ && \
    install -d /usr/include/date/ && \
    install -m644 libcron/externals/date/include/date/* /usr/include/date/ && \
    cd .. && \
    #git clone https://github.com/ToruNiina/toml11 --branch="v4.3.0" --depth=1 && \
    git clone https://github.com/ToruNiina/toml11 --depth=1 && \
    cd toml11 && \
    cmake -DCMAKE_CXX_STANDARD=11 -DCMAKE_BUILD_TYPE=Release . && \
    make install -j $THREADS && \
    cd .. && \
    #git clone https://github.com/sxyzy1016/subconverter --depth=1 && \
    git clone https://github.com/MetaCubeX/subconverter --depth=1 && \
    cd subconverter && \
    patch -p1 < /0001-regGetMatch-Proxy-doesnt-work-for-Glados-yaml.patch && \
    #patch -p1 < /0002-Modified-Version.patch && \
    patch -p1 < /0003-Default-Loglevel-INFO.patch && \
    patch -p1 < /0004-Default-Loglevel-INFO-in-toml.patch && \
    [ -n "$SHA" ] && sed -i 's/\(v[0-9]\.[0-9]\.[0-9]\)/\1-'"$SHA"'/' src/version.h;\
    #python3 -m --break-system-packages ensurepip && \
    #python3 -m --break-system-packages pip install gitpython && \
    python3 scripts/update_rules.py -c scripts/rules_config.conf && \
    cmake -DCMAKE_BUILD_TYPE=Release . && \
    make -j $THREADS && \
    cp /subconverter/subconverter /usr/bin/subconverter && \
    cp -r /subconverter/base /base


FROM node:current-alpine AS subweb_dist
WORKDIR /

COPY 0001-Add-myown-backend-option-to-the-converter.patch /
COPY 0002-use-new-version-of-node.patch /
COPY 0003-Add-SATMOS-to-remote-configs.patch /

RUN apk add --no-cache git patch && \
    git clone --depth=1 https://github.com/CareyWang/sub-web && \
    cd sub-web && \
    patch -p1 < /0001-Add-myown-backend-option-to-the-converter.patch && \
    patch -p1 < /0002-use-new-version-of-node.patch && \
    patch -p1 < /0003-Add-SATMOS-to-remote-configs.patch && \
    #sed -i 's|http://127.0.0.1:25500|https://sub-licorico.koyeb.app|g' src/views/Subconverter.vue && \
    yarn install && \
    yarn build

FROM nginx:stable-alpine

RUN apk add --no-cache \
    libcurl \
    libstdc++ \
    ca-certificates \
    tzdata && \
    apk add --no-cache --virtual subconverter-deps pcre2 libcurl yaml-cpp

COPY --from=subconverter_bins /usr/bin/subconverter /usr/bin/subconverter
COPY --from=subconverter_bins /base /base

COPY --from=subweb_dist /sub-web/dist /usr/share/nginx/html

COPY subweb.conf /etc/nginx/conf.d/default.conf

RUN echo '#!/bin/sh' > /docker-entrypoint.d/40-subconverter.sh && \
    echo "unset PORT" >> /docker-entrypoint.d/40-subconverter.sh && \
    echo 'cd /base && nohup sh -c "subconverter 2>&1 &"' >> /docker-entrypoint.d/40-subconverter.sh && \
    chmod +x /docker-entrypoint.d/40-subconverter.sh

WORKDIR /base
