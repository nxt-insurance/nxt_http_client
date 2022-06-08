# v1.0.4 2022-05-30
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
