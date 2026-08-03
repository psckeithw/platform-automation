 # Agent Research Prompt: RLDatix Contraxx / Contract Management Release Monitoring

## Objective

Determine the authoritative release-information source(s) for the RLDatix products used by American Heart Association, specifically:

- Contraxx
- Contract Management
- intelligentcontract
- Optimus (if it exists)
- Any successor/rebranded versions of the above

The primary goal is to identify stable, machine-readable mechanisms that can be monitored automatically from Azure DevOps or PowerShell to detect:

- New releases
- Updated release notes
- Maintenance notifications
- Customer advisories
- Advance release schedules
- Planned outages

---

# Critical Finding

The most important lead discovered so far is:

```text
https://grc-support.rldatix.com/
```

Specifically:

```text
https://grc-support.rldatix.com/hc/en-us/search?query=release%20notes
```

This appears to be a dedicated RLDatix Governance, Risk & Compliance (GRC) support portal and is likely more relevant to Contraxx than any public RLDatix marketing site. The portal uses a Help Center structure (`/hc/en-us/...`) that resembles Zendesk-style implementations.

This portal should become the primary focus of research.

Confidence: HIGH

---

# Previously Confirmed Findings

## Ecteon Acquisition

RLDatix acquired Ecteon on February 9, 2021. RLDatix explicitly identifies Contraxx as an Ecteon product. Ecteon's Contraxx solution is described as a contract management platform. 【1-48d6d6】【2-b8f637】

Relationship:

```text
Ecteon
↓
Contraxx
↓
RLDatix acquisition
↓
RLDatix Contract Management
```

Confidence: CONFIRMED

---

## Current Contract Management Surface

Public RLDatix content references:

- Contract Management
- Contract Lifecycle Management
- intelligentcontract powered by RLDatix

rather than prominently marketing "Contraxx" itself. 【3-61d517】【4-bd891d】【5-eb228a】

Confidence: HIGH

---

## intelligentcontract

Discovered:

```text
https://portal.intelligentcontract.com/
```

RLDatix branding appears directly on the login page. The site identifies itself as a cloud-based contract management solution. 【3-61d517】

Support portal:

```text
https://support.intelligentcontract.com/
```

A public support environment exists containing documentation, forums, feature discussions, and release notes. 【6-c35989】

Confidence: CONFIRMED

---

# Existing Release Note Evidence

Public release notes already discovered:

```text
https://support.intelligentcontract.com/support/discussions/22000044599
```

Examples:

```text
Release Notes May 2025
Release Notes April 2025
Release Notes March 2025
Release Notes January 2025
Release Notes December 2024
Release Notes November 2024
```

These are exposed through public discussion/forum topics. 【7-a5dfed】

Individual examples:

```text
https://support.intelligentcontract.com/support/discussions/topics/22000016773
https://support.intelligentcontract.com/support/discussions/topics/22000016679
https://support.intelligentcontract.com/support/discussions/topics/22000016653
https://support.intelligentcontract.com/support/discussions/topics/22000016557
```

Release note entries contain:

- Change identifiers
- Feature descriptions
- Feature enhancements
- Documentation references

【8-de62fd】【9-b7f55f】【10-4e6028】【11-2477dc】

Confidence: CONFIRMED

---

# Optimus Investigation Status

No public evidence has been found for a product named:

```text
Optimus
```

However, RLDatix does have:

```text
Allocate Optima
```

which is a workforce rostering product. 【12-3c01a7】【13-babe03】

Current status:

```text
Optimus = Unsupported
Optima = Confirmed RLDatix product
```

The possibility remains that:

- AHA internally refers to an environment as Optimus
- Optimus is a tenant name
- Optimus is a customer-defined instance
- Optimus is legacy branding

Further validation required.

Confidence: LOW

---

# Primary Research Questions

## Question 1

Determine whether:

```text
Contraxx
=
intelligentcontract
=
RLDatix Contract Management
```

are:

- identical products
- separate products
- migration paths
- overlapping brands

Evidence required.

---

## Question 2

Determine whether:

```text
grc-support.rldatix.com
```

contains:

- Contraxx release notes
- Contract Management release notes
- intelligentcontract release notes
- customer advisories
- advance deployment schedules
- maintenance notices

Evidence required.

---

## Question 3

Determine platform technology behind:

```text
grc-support.rldatix.com
```

Specifically:

### Zendesk

Check:

```text
/api/v2/help_center/categories.json
/api/v2/help_center/sections.json
/api/v2/help_center/articles.json
/api/v2/help_center/articles/search.json
```

Verify endpoints rather than assuming.

---

## Question 4

Determine if machine-readable feeds exist.

Look for:

### RSS

```text
/rss
/feed
```

### Atom

```text
.atom
```

### JSON

```text
.json
```

### Search APIs

```text
search.json
```

### Changelog APIs

```text
release-notes
release-calendar
maintenance
announcements
```

---

# High Priority Endpoint Discovery

Probe and validate:

```text
https://grc-support.rldatix.com/api/v2/help_center/categories.json
https://grc-support.rldatix.com/api/v2/help_center/sections.json
https://grc-support.rldatix.com/api/v2/help_center/articles.json
https://grc-support.rldatix.com/api/v2/help_center/articles/search.json?query=release
https://grc-support.rldatix.com/api/v2/help_center/articles/search.json?query=contract
https://grc-support.rldatix.com/api/v2/help_center/articles/search.json?query=contraxx
https://grc-support.rldatix.com/api/v2/help_center/articles/search.json?query=intelligentcontract
https://grc-support.rldatix.com/api/v2/help_center/articles/search.json?query=maintenance
https://grc-support.rldatix.com/api/v2/help_center/articles/search.json?query=advisory
```

Determine:

- response format
- authentication requirements
- pagination
- identifiers
- timestamps
- update dates
- machine-readable metadata

---

# Desired Deliverables

## Product Relationship Map

```text
Ecteon
↓
Contraxx
↓
?
↓
intelligentcontract
↓
?
↓
RLDatix Contract Management
```

Only use evidence.

---

## Source Inventory

For each source:

```text
URL
Purpose
Authentication
Public/Private
Product
Source Type
```

---

## Endpoint Inventory

For each endpoint:

```text
URL
Method
Authentication
Response Format
Pagination
Unique IDs
Date Fields
Usefulness
```

---

## Monitoring Recommendations

Rank sources:

```text
Excellent
Good
Limited
Not Usable
```

Include justification.

---

## Azure DevOps Design Recommendation

Determine:

### Best endpoint to poll

### Best identifier to track

### Best field for detecting changes

### Best method for detecting:

- new releases
- updated releases
- maintenance notifications

---

# Current Assessment

Most likely monitoring priority order:

1. `grc-support.rldatix.com`
2. GRC Help Center APIs (if exposed)
3. GRC release-note search results
4. intelligentcontract release-note forum
5. RLDatix authenticated support portal
6. Public RLDatix knowledge bases

The GRC support portal is currently the strongest lead and should receive the majority of research effort.

---

# Auth Investigation Findings

## grc-support.rldatix.com

All probed endpoints return **HTTP 401** or redirect to a sign-in page:

```text
/api/v2/help_center/categories.json       → 401
/api/v2/help_center/sections.json        → 401
/api/v2/help_center/articles.json        → 401
/api/v2/help_center/articles/search.json → 401
/rss                                     → HTML login page
/feed                                    → HTML login page
```

Portal behavior:
- Returns an HTML sign-in page ("Sign in to Governance, Risk & Compliance").
- SSO options visible: Converge, PX & Growth (SocialClimb).
- No anonymous/anonymous-readable content observed.
- All content is behind authentication; no public article or category data is accessible.

Decision required:
1. Does AHA hold active subscription credentials for this portal?
2. Are SSO credentials (Converge / SocialClimb) available to the automation system?
3. If yes, what is the mechanism: session cookie, API token, bearer token?
4. Is there a rate-limit or terms-of-service restriction on automated polling?

The Zendesk Help Center API v2 endpoints are the correct structure once auth is resolved, but they are unusable without valid credentials.

---

## support.intelligentcontract.com

Release notes are accessible via the public discussion/forum pages without login:

```text
https://support.intelligentcontract.com/support/discussions/22000044599  → public HTML
https://support.intelligentcontract.com/support/discussions/topics/22000016773 → public HTML
```

Discovery:
- No API token or auth required to read forum topics.
- A `search.json` endpoint returns `[]` (empty), but direct topic URLs return structured HTML.
- No RSS or Atom feeds found (both return 404).
- This source is currently machine-readable only via HTML scraping.

Machine-readability assessment:
- Structured HTML, not JSON. Regex or HTML parser required.
- Topic IDs are numeric and stable (`22000044599` style).
- No authenticated API discovered; all probing returned 406/404/empty results.

---

# Current Overall Assessment

| Source | Auth Required | Machine-Readable | Recommended Next Step |
|---|---|---|---|
| grc-support.rldatix.com | Yes | Yes (Zendesk API v2) | Obtain AHA credentials / SSO mapping |
| support.intelligentcontract.com | No | Partial (HTML) | Implement HTML scraper for topic pages |
| RLDatix public marketing sites | No | No | Not viable for release monitoring |

Updated monitoring priority order:

1. `grc-support.rldatix.com` (blocked on auth — highest value once resolved)
2. `support.intelligentcontract.com` discussions (no auth, HTML-scrape viable)
3. Public RLDatix knowledge bases (not viable for release notes)