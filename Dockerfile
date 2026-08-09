ARG STALWART_VERSION=0.16.16
ARG STALWART_CLI_VERSION=1.0.12

FROM debian:trixie-slim AS cli
ARG TARGETARCH
ARG STALWART_CLI_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && case "$TARGETARCH" in \
        amd64) target=x86_64-unknown-linux-musl ;; \
        arm64) target=aarch64-unknown-linux-musl ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && archive="stalwart-cli-${target}.tar.xz" \
    && base="https://github.com/stalwartlabs/cli/releases/download/v${STALWART_CLI_VERSION}" \
    && curl -fsSLo "/tmp/${archive}" "${base}/${archive}" \
    && curl -fsSLo "/tmp/${archive}.sha256" "${base}/${archive}.sha256" \
    && cd /tmp \
    && sha256sum -c "${archive}.sha256" \
    && tar -xJf "${archive}" \
    && install -m 0755 "stalwart-cli-${target}/stalwart-cli" /usr/local/bin/stalwart-cli

FROM docker.io/stalwartlabs/stalwart:v${STALWART_VERSION}@sha256:66ae90f2753ec1dabd70f69cad7da9f0598d2628a04193ce2b08c7263d47aced
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu jq \
    && rm -rf /var/lib/apt/lists/*
COPY --from=cli /usr/local/bin/stalwart-cli /usr/local/bin/stalwart-cli
COPY entrypoint.sh /usr/local/bin/railway-entrypoint
RUN chmod 0755 /usr/local/bin/railway-entrypoint
ENTRYPOINT ["/usr/local/bin/railway-entrypoint"]
