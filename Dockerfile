FROM  metacubex/subconverter:latest AS subconverter_bins

FROM careywong/subweb:latest AS subweb_dist

FROM nginx:stable-alpine

RUN apk add --no-cache \
    libcurl \
    libstdc++ \
    ca-certificates \
    tzdata && \
    apk add --no-cache --virtual subconverter-deps pcre2 libcurl yaml-cpp && \
    ln -s libyaml-cpp.so.0.8 /usr/lib/libyaml-cpp.so.0.7

COPY --from=subconverter_bins /usr/bin/subconverter /usr/bin/subconverter
COPY --from=subconverter_bins /base /base

COPY --from=subweb_dist /usr/share/nginx/html /usr/share/nginx/html

COPY subweb.conf /etc/nginx/conf.d/default.conf

RUN echo '#!/bin/sh' > /docker-entrypoint.d/40-subconverter.sh && \
    echo "unset PORT" >> /docker-entrypoint.d/40-subconverter.sh && \
    echo 'cd /base && nohup sh -c "subconverter 2>&1 &"' >> /docker-entrypoint.d/40-subconverter.sh && \
    chmod +x /docker-entrypoint.d/40-subconverter.sh

WORKDIR /base
