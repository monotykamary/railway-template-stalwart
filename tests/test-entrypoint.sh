#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

for script in "$repo/entrypoint.sh" "$repo/tests/test-entrypoint.sh"; do
  sh -n "$script"
done

export POSTGRES_HOST='postgres.railway.internal'
export POSTGRES_PORT=5432
export POSTGRES_DATABASE='railway'
export POSTGRES_USER='postgres'
export POSTGRES_PASSWORD='quote" slash\ dollar$ amp& newline
value'
export S3_BUCKET='mail-blobs-test'
export S3_REGION='auto'
export S3_ENDPOINT='https://storage.example.test'
export S3_ACCESS_KEY_ID='access-id'
export S3_SECRET_ACCESS_KEY='secret"$&\value'
export MAIL_HOSTNAME='mail.example.test'
export MAIL_DOMAIN='example.test'
export STALWART_BOOTSTRAP_PASSWORD='admin-secret'
export RAILWAY_ENTRYPOINT_RENDER_ONLY=1

output=$("$repo/entrypoint.sh")
printf '%s' "$output" | jq -e '
  .serverHostname == "mail.example.test" and
  .defaultDomain == "example.test" and
  .requestTlsCertificate == false and
  .dataStore.authSecret.variableName == "POSTGRES_PASSWORD" and
  .blobStore.secretKey.variableName == "S3_SECRET_ACCESS_KEY" and
  .blobStore.verifyAfterWrite == true and
  (.blobStore | tostring | contains("secret\"$&\\value") | not) and
  (.dataStore | tostring | contains("quote\"") | not)
' >/dev/null

if printf '%s' "$output" | grep -F "$POSTGRES_PASSWORD" >/dev/null; then
  echo 'PostgreSQL secret leaked into bootstrap JSON' >&2
  exit 1
fi
if printf '%s' "$output" | grep -F "$S3_SECRET_ACCESS_KEY" >/dev/null; then
  echo 'S3 secret leaked into bootstrap JSON' >&2
  exit 1
fi

if POSTGRES_PORT=invalid "$repo/entrypoint.sh" >/dev/null 2>&1; then
  echo 'Invalid PostgreSQL port was accepted' >&2
  exit 1
fi

echo 'entrypoint tests passed'
