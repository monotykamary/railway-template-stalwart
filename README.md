# Stalwart Mail on Railway

A Railway deployment of [Stalwart Mail & Collaboration Server](https://stalw.art/) using Railway PostgreSQL for metadata and a Railway Bucket for raw messages, attachments, Sieve scripts, and files.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/stalwart-mail-s3?referralCode=ZqgrJ0)

## What this deploys

- Stalwart Server `v0.16.18`
- Stalwart CLI `v1.0.12` for first-boot configuration
- Railway PostgreSQL for accounts, mailbox state, indexes, and configuration
- Railway Bucket through Stalwart's S3-compatible blob store
- A small persistent volume for `/etc/stalwart/config.json`

The adapter performs Stalwart's supported bootstrap flow. It keeps bucket and database secrets as environment-variable references rather than writing secret values into the persisted configuration.

## Required setup

During deployment, set:

- `MAIL_HOSTNAME`: the public mail hostname, such as `mail.example.com`
- `MAIL_DOMAIN`: the email domain, such as `example.com`

Open the generated Railway HTTPS domain and sign in to `/admin` with user `admin` and the generated `STALWART_BOOTSTRAP_PASSWORD` variable. This is Stalwart's fallback recovery administrator. Reset the permanent `admin@MAIL_DOMAIN` account password in the WebUI, then remove `STALWART_BOOTSTRAP_PASSWORD` when recovery access is no longer wanted.

## Important mail networking limitations

Railway does not expose arbitrary services on fixed public TCP ports. Its TCP proxy assigns a generated external port, while internet SMTP delivery through MX records requires port 25. Therefore this template is not a standalone internet-facing MX server.

- Use an external inbound SMTP gateway that can relay to a custom host and port.
- Use an outbound SMTP relay unless you are on Railway Pro and have deliberately configured direct SMTP delivery and deliverability controls.
- IMAP, submission, POP3, or ManageSieve can be exposed through a Railway TCP proxy, but clients must use Railway's generated port. A service currently has one public TCP proxy. The template pins `PORT=8080` so adding a TCP proxy does not redirect Railway's HTTP health check to a mail port.
- Railway terminates HTTPS for the administration, JMAP, CalDAV, CardDAV, and WebDAV endpoint on port 8080.

## Persistence and backups

Raw email and files are stored in the Railway Bucket. PostgreSQL stores the metadata needed to interpret those blobs. Losing either makes the deployment incomplete. Back up PostgreSQL and preserve the bucket; the config volume should also remain attached.

## Updating

Version bumps are deliberate. Update the pinned server and CLI versions in `Dockerfile`, review upstream upgrade notes, run the local tests, and repeat live persistence and bucket validation before publishing.

## Sources and licensing

- [Stalwart source](https://github.com/stalwartlabs/stalwart)
- [Stalwart v0.16.18](https://github.com/stalwartlabs/stalwart/releases/tag/v0.16.18)
- [Stalwart documentation](https://stalw.art/docs/)
- [Stalwart CLI v1.0.12](https://github.com/stalwartlabs/cli/releases/tag/v1.0.12)

This adapter is MIT licensed. Stalwart and the derived icon retain their upstream licensing; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
