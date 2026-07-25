# Deploy and Host Stalwart on Railway

## About Hosting Stalwart

Stalwart is an all-in-one mail and collaboration server supporting SMTP, JMAP, IMAP, POP3, CalDAV, CardDAV, and WebDAV. This template pins Stalwart Server v0.16.14 and configures its supported S3 blob backend to use a Railway Bucket. Raw messages, attachments, Sieve scripts, and files go to object storage; Railway PostgreSQL holds accounts, mailbox state, indexes, and server configuration.

## Common Use Cases

- Host JMAP, calendars, contacts, and WebDAV files behind Railway HTTPS
- Store mail bodies and attachments in durable Railway object storage
- Run Stalwart behind an external inbound and outbound SMTP relay
- Evaluate Stalwart's administration and collaboration features

## Dependencies for Stalwart Hosting

### Deployment Dependencies

The template provisions Stalwart, PostgreSQL, a Railway Bucket, and a small configuration volume. You must provide `MAIL_HOSTNAME` and `MAIL_DOMAIN`. First sign-in uses the generated `STALWART_BOOTSTRAP_PASSWORD` with username `admin` at `/admin`.

Internet mail requires external SMTP infrastructure. Railway TCP proxies use generated external ports, so Railway cannot expose the fixed port 25 required by MX delivery. Outbound SMTP is restricted to Pro plans and above; an outbound relay is recommended.

### Implementation Details

The adapter uses Stalwart's official bootstrap API and CLI. PostgreSQL and bucket credentials are wired with Railway service references. Secret values are read from environment variables and are not copied into the persistent Stalwart configuration. Railway HTTPS and health checks are pinned to Stalwart's HTTP listener on port 8080, even if you later enable a generated-port TCP proxy.

After signing in, reset the permanent `admin@MAIL_DOMAIN` account password. Remove the recovery password variable after confirming permanent administrator access if you do not want fallback recovery login.

### Why Deploy Stalwart on Railway?

Railway provides managed PostgreSQL, private S3-compatible buckets, HTTPS, deployment health checks, and a reproducible service topology. This template focuses on Stalwart's web and storage capabilities while documenting Railway's fixed-port SMTP limitation rather than presenting it as a standalone MX server.
