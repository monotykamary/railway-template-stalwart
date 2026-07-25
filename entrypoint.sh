#!/bin/sh
set -eu

config_path=/etc/stalwart/config.json
bootstrap_patch=/tmp/stalwart-bootstrap.json
bootstrap_stdout=/tmp/stalwart-bootstrap.stdout
bootstrap_stderr=/tmp/stalwart-bootstrap.stderr

require() {
  value=$(printenv "$1" 2>/dev/null || true)
  if [ -z "$value" ]; then
    echo "Missing required variable: $1" >&2
    exit 1
  fi
}

for variable in \
  POSTGRES_HOST POSTGRES_PORT POSTGRES_DATABASE POSTGRES_USER POSTGRES_PASSWORD \
  S3_BUCKET S3_REGION S3_ENDPOINT S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY \
  MAIL_HOSTNAME MAIL_DOMAIN
do
  require "$variable"
done

case "$POSTGRES_PORT" in
  *[!0-9]*|'') echo "POSTGRES_PORT must be numeric" >&2; exit 1 ;;
esac

render_bootstrap() {
  jq -n \
    --arg serverHostname "$MAIL_HOSTNAME" \
    --arg defaultDomain "$MAIL_DOMAIN" \
    --arg postgresHost "$POSTGRES_HOST" \
    --argjson postgresPort "$POSTGRES_PORT" \
    --arg postgresDatabase "$POSTGRES_DATABASE" \
    --arg postgresUser "$POSTGRES_USER" \
    --arg s3Bucket "$S3_BUCKET" \
    --arg s3Region "$S3_REGION" \
    --arg s3Endpoint "$S3_ENDPOINT" \
    --arg s3AccessKey "$S3_ACCESS_KEY_ID" \
    '{
      serverHostname: $serverHostname,
      defaultDomain: $defaultDomain,
      requestTlsCertificate: false,
      generateDkimKeys: true,
      dataStore: {
        "@type": "PostgreSql",
        host: $postgresHost,
        port: $postgresPort,
        database: $postgresDatabase,
        authUsername: $postgresUser,
        authSecret: {
          "@type": "EnvironmentVariable",
          variableName: "POSTGRES_PASSWORD"
        }
      },
      blobStore: {
        "@type": "S3",
        region: {
          "@type": "Custom",
          customEndpoint: $s3Endpoint,
          customRegion: $s3Region
        },
        bucket: $s3Bucket,
        accessKey: $s3AccessKey,
        secretKey: {
          "@type": "EnvironmentVariable",
          variableName: "S3_SECRET_ACCESS_KEY"
        },
        securityToken: {"@type": "None"},
        sessionToken: {"@type": "None"},
        verifyAfterWrite: true
      },
      searchStore: {"@type": "Default"},
      inMemoryStore: {"@type": "Default"},
      directory: {"@type": "Internal"},
      tracer: {"@type": "Console"},
      dnsServer: {"@type": "Manual"}
    }'
}

if [ "${RAILWAY_ENTRYPOINT_RENDER_ONLY:-}" = 1 ]; then
  render_bootstrap
  exit 0
fi

mkdir -p /etc/stalwart /var/lib/stalwart
chown -R stalwart:stalwart /etc/stalwart /var/lib/stalwart

if [ -n "${STALWART_BOOTSTRAP_PASSWORD:-}" ]; then
  export STALWART_RECOVERY_ADMIN="admin:$STALWART_BOOTSTRAP_PASSWORD"
fi

if [ ! -s "$config_path" ]; then
  require STALWART_BOOTSTRAP_PASSWORD
  echo "Initializing Stalwart with PostgreSQL metadata and Railway Bucket blobs"
  render_bootstrap > "$bootstrap_patch"
  chmod 600 "$bootstrap_patch"
  chown stalwart:stalwart "$bootstrap_patch"

  STALWART_RECOVERY_MODE_PORT=8081 \
    gosu stalwart /usr/local/bin/stalwart --config "$config_path" &
  server_pid=$!

  cleanup() {
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    rm -f "$bootstrap_patch" "$bootstrap_stdout" "$bootstrap_stderr"
  }
  trap cleanup INT TERM EXIT

  ready=0
  attempt=0
  while [ "$attempt" -lt 90 ]; do
    if curl -fsS http://127.0.0.1:8081/healthz/live >/dev/null 2>&1; then
      ready=1
      break
    fi
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "Stalwart exited during bootstrap" >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  if [ "$ready" -ne 1 ]; then
    echo "Stalwart bootstrap listener did not become ready" >&2
    exit 1
  fi

  if ! HOME=/var/lib/stalwart \
    STALWART_URL=http://127.0.0.1:8081 \
    STALWART_USER=admin \
    STALWART_PASSWORD="$STALWART_BOOTSTRAP_PASSWORD" \
    /usr/local/bin/stalwart-cli update Bootstrap --file "$bootstrap_patch" \
      >"$bootstrap_stdout" 2>"$bootstrap_stderr"
  then
    echo "Stalwart bootstrap configuration failed" >&2
    sed -E 's/(secret|password)[^ ]*/[redacted]/Ig' "$bootstrap_stderr" >&2
    exit 1
  fi

  if [ ! -s "$config_path" ]; then
    echo "Stalwart bootstrap did not create $config_path" >&2
    exit 1
  fi

  kill "$server_pid"
  wait "$server_pid" || true
  rm -f "$bootstrap_patch" "$bootstrap_stdout" "$bootstrap_stderr"
  trap - INT TERM EXIT
  echo "Stalwart initialization complete"
fi

exec gosu stalwart /usr/local/bin/stalwart --config "$config_path"
