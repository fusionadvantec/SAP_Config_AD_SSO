# DAST ZAP Configuration — DevSecOps 360

Authenticated DAST scan configuration for `https://devsecops360.fusion.co.th` using Checkmarx DAST CLI + ZAP.

## Prerequisites

- Docker
- Checkmarx One API key
- Azure AD app registration with `client_credentials` flow

## Files

| File | Purpose |
|---|---|
| `test-auth.yaml` | ZAP automation plan — manual auth + httpsender Bearer injection |
| `AddBearerToken.js` | GraalJS httpsender script — injects `Authorization: Bearer` from `AZURE_TOKEN` env var |
| `Run-DastScan.ps1` | PowerShell launcher (gets AAD token, runs container, uploads to CxOne) |
| `zscaler-root-ca.crt` | Zscaler root CA for corporate SSL inspection |
| `combined-ca-bundle.crt` | Combined CA bundle fallback |

## Quick Start

```powershell
# Set your Checkmarx One API key
$env:CX_APIKEY = "your-api-key"

# Run scan (auto mode — fresh AAD token + httpsender auth)
.\Run-DastScan.ps1 -Mode auto
```

## Modes

| Mode | Description |
|---|---|
| `auto` | Gets fresh Azure AD token, injects via httpsender, runs full DAST web scan |
| `yaml` | Basic scan using YAML plan (no auth) |
| `direct` | Gets token, passes via `--custom-header` to scan command |

## How It Works

1. **Auth Workaround**: ZAP D-2026-07-06 has a bug where `authentication.method: script` fails. Workaround uses `method: manual` + `type: httpsender` script to inject Bearer tokens.
2. **Token Injection**: `AddBearerToken.js` reads `AZURE_TOKEN` env var and adds `Authorization: Bearer <token>` to every outgoing request.
3. **SSL**: Zscaler corporate cert is mounted and trusted inside the container via `update-ca-certificates`.
4. **SPA Coverage**: Since the app is a client-side SPA, routes must be manually listed under `context.urls` in `test-auth.yaml`.

## Scan Configuration

Edit `test-auth.yaml` to add/remove URLs under:

```yaml
context:
  urls:
    - https://devsecops360.fusion.co.th
    - https://devsecops360.fusion.co.th/dashboard
    - https://devsecops360.fusion.co.th/calendar
    - https://devsecops360.fusion.co.th/Heatmap
    - https://devsecops360.fusion.co.th/MyDashboard
    - https://devsecops360.fusion.co.th/Import
    - https://devsecops360.fusion.co.th/Tickets
    - https://devsecops360.fusion.co.th/TicketImport
    - https://devsecops360.fusion.co.th/Pipeline
    - https://devsecops360.fusion.co.th/OKRs
```

## Known Limitations / Blockers

| Issue | Status |
|---|---|
| **ZAP `method: script` auth bug** (D-2026-07-06) | Workaround: manual auth + httpsender |
| **Client (AJAX) spider** not supported by CxOne wrapper | Only traditional spider available — no JS rendering |
| **Multi-domain OAuth2** (Azure AD login redirects to `login.microsoftonline.com`) | ZAP cannot follow external OAuth redirects through the wrapper |
| **`*` wildcard not supported** in `context.urls` | Each SPA route must be listed manually |
| **OpenAPI scan (`dast api`)** — auth injection doesn't work | Only web scan mode is reliable |
| **`requestor` job params** (`requests`, `urls`) not supported | Use `context.urls` instead |
| **`activeScan` job params** (`maxDuration`, `policyDefinition`) not supported | Scan depth controlled via CxOne UI settings |

## Privacy

Before committing, always replace hardcoded secrets with env var references:
- `$ClientSecret = "_V18Q~..."` → `$ClientSecret = $env:AZURE_CLIENT_SECRET`
- `password: _V18Q~...` → `password: ${AZURE_CLIENT_SECRET}`
- Set `$env:CX_APIKEY` at runtime (never hardcoded)

## Archive

Old/experimental files are in the `archive/` directory for reference.
