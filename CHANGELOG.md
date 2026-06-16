# v2.2.0 2026-06-15
- `json_response` now returns `nil` for an empty/204 body instead of raising `JSON::ParserError`.
- Add an opt-in error taxonomy under `NxtHttpClient::Error`. With `config.use_error_taxonomy = true` the client
  raises a typed subclass for an unhandled non-success response instead of returning it:
  - HTTP status: `ClientError` with `BadRequest` (400), `Unauthorized` (401), `Forbidden` (403),
    `NotFound` (404), `UnprocessableEntity` (422), `TooManyRequests` (429); `ServerError` (5xx).
  - Network (`return_code`-mapped code-0): `NetworkError` with `Timeout`, `ConnectionFailed`,
    `NameResolutionError`, `TlsError`; `CertificateError` (cert verification — a sibling, not a child).
- Retryable errors share base classes — `retry_on NxtHttpClient::Error::NetworkError, NxtHttpClient::Error::ServerError`.
  4xx, `CertificateError` and 429 are excluded (429 retry policy is left to consumers).
- `map_error(status, klass)` DSL to override the mapping per client (e.g. a domain `ValidationFailed` that
  parses the body); inherited by subclasses.
- `config.use_error_taxonomy` defaults to `false`, so the upgrade is backwards compatible — existing behavior
  (and `raise_response_errors`) is unchanged until you opt in. A consumer's own `on(<code>)`/`on(:error)`/
  `on(:timed_out)` callback always takes precedence over the taxonomy.

# v2.1.0 2024-06-05
- Bump dependencies

# v2.0.1 2024-02-22
- Handle response code for empty strings and blank responses

# v2.0.0 2023-08-31
- Add simpler initialization interface for one-off clients
- Add helpers for common config options
- Require request timeouts

# v1.1.0 2023-04-03
- Introduce a Typhoeus::Hydra interface for batch executions

# v1.0.4 2022-06-08
- Fix bug where callbacks were shared between unrelated child client class ([#130](https://github.com/nxt-insurance/nxt_http_client/pull/130))

# v1.0.3 2022-02-08

- Relax dependency version constraints, allow activesupport < 8

# v1.0.2 2021-02-17

### Update NxtHttpClient::Error
- delegate timed_out? and status_message to response

# v1.0.1 2021-02-04

### Update NxtRegistry
- update nxt_registry to 0.3.8

# v1.0.0 2021-01-10

### Breaking changes
- renamed register_response_handler to _response_handler
- replace before_fire and after_fire hooks with proper callbacks before, after and around fire

### Updated
- error now includes more information about request and headers

# v0.3.4 2021-01-05

### Updated

- Loosen ActiveSupport version requirement to allow 6.1

# v0.3.3 2020-09-30

### Updated NxtRegistry

[Compare v0.3.2...v0.3.3](https://github.com/nxt-insurance/nxt_http_client/compare/v0.3.2...v0.3.3)

# v0.2.10 2020-03-10

### Refactored

- [internal] Added CHANGELOG.MD
- Refactored a bit

[Compare v0.2.9...v0.3.0](https://github.com/nxt-insurance/nxt_http_client/compare/v0.2.9...v0.2.10)
