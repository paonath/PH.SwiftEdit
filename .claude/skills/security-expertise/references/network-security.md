---
name: "network-security"
description: "Network and transport security reference covering Zero Trust (NIST SP 800-207), TLS 1.2/1.3 (RFC 8446), HTTP security headers, CORS, reverse proxy hardening, and OIDC/Entra ID."
---

# Network and Transport Security Reference

## Scope and Zero Trust Baseline

- Evaluate transport configurations, API gateways, reverse proxies (IIS, nginx, YARP, Kestrel), CORS policies, HTTP security headers, rate limiting, and OIDC/OAuth 2.1 federation.
- Enforce **Zero Trust Architecture** (`NIST SP 800-207`): never grant implicit trust based on internal network location (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`); authenticate and authorize every service-to-service and client-to-API request.
- Enforce `security-secrets-policy` across TLS certificates, private keys, and OIDC client secrets.

## Transport, Headers, and Federation Audit Matrix

| Control Area | Standard / CWE | Vulnerable Pattern | Mandatory Hardening Standard |
| :--- | :--- | :--- | :--- |
| TLS Protocol & Ciphers | `RFC 8446`, `NIST SP 800-52r2`, `CWE-326` | Enabling SSLv3, TLS 1.0, TLS 1.1, RSA key transport without forward secrecy, or `ServerCertificateCustomValidationCallback = DangerousAcceptAnyServerCertificateValidator` | Enforce `TLS 1.3` (`TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`) and `TLS 1.2` ECDHE-GCM only; reject certificate validation bypasses in non-test code |
| HTTP Security Headers | `OWASP A05:2021`, `CWE-693` | Missing HSTS, permissive `Content-Security-Policy` (`unsafe-inline`, `unsafe-eval`, `*`), missing `X-Content-Type-Options` or `Frame-Options` | Emit `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`, and nonce/hash-based `Content-Security-Policy` |
| CORS Configuration | `OWASP A05:2021`, `CWE-942` | `AllowAnyOrigin()` combined with `AllowCredentials()`, wildcard subdomain reflection (`Origin` header echoed without allowlist) | Bind explicit origin allowlists (`WithOrigins(configuredOrigins)`), restrict methods/headers, and prohibit wildcard origins when `AllowCredentials()` is enabled |
| Reverse Proxy & Forwarded Headers | `CWE-290`, `CWE-348` | Using `UseForwardedHeaders()` without `KnownProxies` / `KnownNetworks`, allowing spoofed `X-Forwarded-For` or `X-Forwarded-Host` (host header poisoning & rate-limit bypass) | Configure explicit `ForwardedHeadersOptions.KnownProxies` / `KnownNetworks`, set `ForwardLimit = 1`, and configure explicit `HostFilteringOptions.AllowedHosts` |
| Rate Limiting & DoS Protection | `API4:2023`, `CWE-770` | Unbounded anonymous login/token endpoints, missing request body size limits (`MaxRequestBodySize = null`), or missing request timeouts | Enforce `UseRateLimiter` partitioned by authenticated user or verified client IP, explicit `MaxRequestBodySize`, and `RequestTimeouts` |
| OIDC / OAuth 2.1 / Entra ID | `RFC 6749`, `CWE-347` | `ValidateIssuer = false`, `ValidateAudience = false`, `ValidateLifetime = false`, accepting `alg: none`, or storing tokens in `localStorage` | Enforce strict `TokenValidationParameters` (`ValidateIssuer`, `ValidateAudience`, `ValidateLifetime`, `ValidateIssuerSigningKey`, `ClockSkew <= 2 min`), PKCE (`S256`), and `HttpOnly; Secure; SameSite=Strict` cookies or BFF pattern |

## Cross-Domain Cascade Signals

- Emit `cascades_to: ["code-security"]` when reverse proxy or OIDC misconfigurations expose endpoints to auth bypass or SSRF.
- Emit `cascades_to: ["gdpr-compliance"]` when third-party CDNs, analytics endpoints, or cross-region reverse proxies transmit client IPs or telemetry outside the EEA (GDPR Arts. 28, 44-49).
- Emit `cascades_to: ["security-testing-tdd"]` for expired/forged JWT, disallowed CORS origin, and spoofed `X-Forwarded-For` integration test contracts.

## Verification Checklist

- [X] TLS 1.2/1.3 enforced with zero certificate validation bypasses
- [X] `Strict-Transport-Security`, `Content-Security-Policy`, and `X-Content-Type-Options: nosniff` configured
- [X] CORS policies use explicit origin allowlists and never pair wildcards with credentials
- [X] `ForwardedHeadersOptions` restricts `KnownProxies`/`KnownNetworks`
- [X] OIDC/JWT validation enforces issuer, audience, lifetime, and signing key verification
