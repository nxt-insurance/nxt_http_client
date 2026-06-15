# v2.2.0 2026-06-15
- Add `NxtHttpClient::TransientError` marker module and `return_code`-mapped network error subclasses
  under `NxtHttpClient::Error`: `NetworkError`, `Timeout`, `ConnectionFailed`, `NameResolutionError`,
  `TlsError` (all transient/retryable) and `CertificateError` (cert verification — not transient).
- Consumers can `retry_on NxtHttpClient::TransientError` without per-client `on(0)` wiring.
- **Behavior change**: a code-0 (network failure) response now raises the mapped error by default.
  Opt out with `config.raise_network_errors = false` to restore returning the code-0 response.
  Backwards compatible for anyone rescuing `NxtHttpClient::Error` (all subclasses inherit from it);
  exact-class checks and error-message strings change.

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
