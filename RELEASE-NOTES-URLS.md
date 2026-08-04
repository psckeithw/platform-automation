# Release Notes Endpoint Research for Third-Party Applications

Prepared for AI-agent use.  
Purpose: Identify public or semi-public release-note, product-update, changelog, support, community, status, S3/CDN, app-store, or version-monitoring endpoints for reviewed third-party applications.

---

## Usage Guidance for AI Agents

- Treat **Excellent**, **Very High**, and **High** sources as the primary automation candidates.
- Distinguish between true release-note repositories and lower-confidence sources such as blogs, PR feeds, login-page version strings, or marketplace listings.
- For vendors with customer-gated support portals, use authenticated access only if explicitly authorized by the organization.
- Do not scrape authenticated portals, S3 buckets, or support sites aggressively. Use low-frequency polling and respect robots, rate limits, and terms of use.
- For corporate environments, release-monitoring automation may trigger security monitoring if it performs broad endpoint enumeration. Use allowlisted URLs and predictable polling only.

---

# Section 1: High-or-Above Quality Release Sources

## Excellent

### Qualtrics

1. `https://community.qualtrics.com/product-release-notes-96`  
   Official Product Release Notes community with weekly and monthly release notes, 400+ topics, product-specific updates, and subscription capability. citeturn13search131turn13search140

2. `https://community.qualtrics.com/product-release-notes-96/weekly-product-release-notes-july-1-2026-33472`  
   Example weekly release note showing current and upcoming features across Survey Platform, XM Discover, Data Modeler, Tickets, XM App, and XM Platform. citeturn13search132

3. `https://community.qualtrics.com/product-release-notes-96/monthly-product-release-notes-march-6-2025-to-april-2-2025-31881`  
   Example monthly release summary covering multiple product areas and release windows. citeturn13search143

---

### Smartsheet

1. `https://www.smartsheet.com/content-center/product-news/release-notes/all`  
   Official Release News portal with frequent release notes, API updates, action-required notices, product enhancements, and subscription option. citeturn15search157turn15search162

2. `https://community.smartsheet.com/en/categories/product-announcements`  
   Product announcement community with general availability notices, deprecation notices, feature releases, and API-related announcements. citeturn15search159

3. `https://community.smartsheet.com/discussion/69251/receive-the-latest-smartsheet-product-release-notes-on-new-capabilities-and-enhancements-by-email`  
   Subscription information for release-note emails, including daily commercial-platform updates and monthly Smartsheet Gov updates. citeturn15search162

---

### OneSpan

1. `https://docs.onespan.com/docs/oss-release-notes`  
   Central OneSpan Sign release notes landing page with current releases, previous releases, mobile, embedded integrations, and certificate client release categories. citeturn10search96

2. `https://docs.onespan.com/docs/onespan-sign-release-notes`  
   OneSpan Sign release notes with formal release train examples such as 26.R4 and 26.R3. citeturn10search97

3. `https://docs.onespan.com/sec/docs/oca-release-notes`  
   OneSpan Cloud Authentication release notes with current releases, prior releases, breaking-change notices, and security-related updates. citeturn10search108

4. `https://docs.onespan.com/docs/identity-verification-release-notes`  
   OneSpan Identity Verification release notes repository. citeturn10search107

5. `https://www.onespan.com/about/news-releases`  
   Corporate news releases for major product launches, integrations, acquisitions, and platform direction. citeturn10search103

---

### Deque Axe

1. `https://docs.deque.com/`  
   Official Deque documentation portal covering axe-core, Axe DevTools, Axe Monitor, Axe Reports, Axe Developer Hub, Axe Auditor, and related products. citeturn6search70

2. `https://docs.deque.com/axe-release-impact/4.11.0/en/release-notes/`  
   Example axe-core release-impact page with features, bug fixes, affected products, and rule impact details. citeturn6search56

3. `https://github.com/dequelabs/axe-core/releases`  
   Official GitHub releases for axe-core with tagged releases, version history, fixes, and source archive links. citeturn6search58

4. `https://docs.dequelabs.com/devtools-for-web/4/en/rn-node/`  
   Axe DevTools for Web Node.js package release notes with versioned release history and package-level changes. citeturn6search65

5. `https://docs.deque.com/devtools-for-web/4/en/devtools-4-106-1/`  
   Example Axe DevTools Extension release note page. citeturn6search62

6. `https://www.deque.com/resources/topic/deque-news-updates/`  
   Deque company news and product update feed for strategic announcements and product launches. citeturn6search67

---

### Diligent Boards

1. `https://help.diligentoneplatform.com/helpdocs/boards/en-us/Content/release_notes/release-notes-boards.htm`  
   Official Diligent Boards release notes landing page covering Boards iOS, Boards Web Admin, Boards Web Director, add-ons, Questionnaires, Minutes, and Messenger. citeturn8search72

2. `https://help.diligentoneplatform.com/helpdocs/boards/en-us/Content/release_notes/release-notes-bwa.htm`  
   Boards Web Admin release notes with dated feature and enhancement entries, including GovernAI, Forward Planner, Agenda Builder, and Smart Minutes. citeturn8search73

3. `https://connect.diligent.com/s/productupdates-boards?language=en_US`  
   Product Updates portal for Boards announcements, UI updates, accessibility improvements, voting features, and Secure File Sharing updates. citeturn8search74

4. `https://connect.diligent.com/s/topic/0TO6T000001Z3LKWA0/release-notes?language=en_US`  
   Diligent Connect release notes topic. citeturn8search83

5. `https://www.diligent.com/resources/blog/ai-innovations-board-prep-entity-workflows`  
   Product blog covering recent Diligent Boards and Entities updates. citeturn8search75

---

### FileTrail

1. `https://support.litera.com/article/FileTrail-5-24-0-Release-Notes`  
   Current FileTrail 5.24.0 release notes with release date, highlights, new features, security updates, ElasticSearch authorization, Email Analyzer updates, and Matter Mobility improvements. citeturn16search171

2. `https://support.litera.com/article/FileTrail-v5220-Release-Notes-537564`  
   FileTrail v5.22.0 release notes with detailed feature descriptions, connector changes, document viewer changes, and Matter Mobility updates. citeturn16search165

3. `https://support.litera.com/article/FileTrail-v5-21-0-Release-Notes`  
   FileTrail v5.21.0 release notes and v5.20.1 hotfix information. citeturn16search166

4. `https://support.litera.com/article/FileTrail-v5-22-7-Release-Notes`  
   FileTrail v5.22.7 hotfix release notes. citeturn16search174

5. `https://support.litera.com/article/FileTrail-Documentation-Downloads`  
   FileTrail documentation downloads, including admin guides, API guides, integration guides, upgrade guides, and compatibility resources. citeturn16search175

6. `https://mpa.filetrail.com/DataManager/Login.aspx`  
   Public login page exposing deployed version `5.22.9.1`, useful for version monitoring. citeturn16search167

---

## Very High

### Coda / Superhuman Docs

1. `https://coda.io/product/whats-new`  
   Official Coda “What’s New” page with monthly product updates, AI features, MCP improvements, connectors, platform changes, and Superhuman Docs transition information. citeturn3search25

2. `https://help.superhuman.com/hc/en-us/articles/46210093285773-What-s-changing-Coda-becomes-Superhuman-Docs`  
   Official transition documentation explaining Coda becoming Superhuman Docs, URL changes, product continuity, and new capabilities. citeturn3search30

3. `https://help.coda.io/hc/en-us/articles/39555750800397-Coda-s-2025-UI-refresh`  
   Coda help article documenting UI refresh changes and workflow impacts. citeturn3search31

4. `https://releasebot.io/updates/coda`  
   Third-party release aggregation feed for Coda updates. citeturn3search26

5. `https://releases.sh/superhuman/coda`  
   Third-party release and app-version timeline for Coda/Superhuman Docs. citeturn3search28

---

### CyberGrants / Bonterra

1. `https://bonterra.zendesk.com/hc/en-us/sections/40326415973399-Release-Notes`  
   Bonterra release notes repository with year-based release note archives from 2019 through 2026. citeturn5search48

2. `https://community.bonterratech.com/product-updates`  
   Bonterra Central Community product updates feed with product filtering, including CyberGrants. citeturn5search49

3. `https://www.bonterratech.com/product/cybergrants`  
   Bonterra CyberGrants product page for product verification and major platform positioning. citeturn5search46

4. `https://trustcenter.bonterratech.com/`  
   Bonterra Trust Center with compliance, security, privacy, and AI governance information. citeturn5search52

---

## High

### PPM Pro / Planview

1. `https://success.planview.com/Planview_PPM_Pro/Release_Information/New_Features_and_Release_Notes/`  
   Authoritative release-note path repeatedly referenced by Planview community and status-page release notices, though direct access may depend on customer permissions. citeturn2search12turn2search13turn2search22

2. `https://community.planview.com/ppm-pro-70`  
   Planview Customer Community PPM Pro area with product discussions, roadmap questions, and release-related topics. citeturn2search11

3. `https://community.planview.com/learn-and-share-72`  
   Community area containing example PPM Pro release announcements such as May 2025 bug fixes and improvements. citeturn2search12

4. `https://status.planview.com/issues/699710cfa877245b6cb0eca2`  
   Example PPM Pro February 2026 release deployment notice with release-note link. citeturn2search13

5. `https://status.planview.com/issues/6a17022323140279f5a12447`  
   Example PPM Pro May 2026 release update notice. citeturn2search22

6. `https://community.planview.com/product-updates`  
   Planview Product Updates page. citeturn2search21

---

### Optimus / RLDatix

1. `https://www.rldatix.com/en-nam/support/`  
   RLDatix North America support page explicitly stating authenticated users can view alerts, knowledge articles, upcoming release notes, release notes, and training materials. citeturn11search109turn12search128

2. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/Release_Notes/DCIQ/downloads/DCIQ.2023.R8.2_CR_release_notes.pdf`  
   Public S3-hosted RLDatix DatixCloudIQ release note PDF for DCIQ.2023.R8.2. citeturn12search126

3. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/6.16+New+Features+%26+Enhancements/Documentation+%26+Accessories/RL6_ReleaseNotes_6.16.pdf`  
   Public S3-hosted RL6 v6.16 release notes. citeturn12search122

4. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/6.15+New+Features+%26+Enhancements/Documentation+%26+Accessories/RL6_ReleaseNotes_6.15.pdf`  
   Public S3-hosted RL6 v6.15 release notes. citeturn12search123

5. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/6.13+New+Features+and+Enhancements/RL6_ReleaseNotes_6.13.pdf`  
   Public S3-hosted RL6 v6.13 release notes. citeturn12search124

6. `https://www.rldatix.com/en-nam/company/news`  
   RLDatix news page with product, AI, platform, workforce, and patient-safety announcements. citeturn11search116

7. `https://rld.rldatix.com/en-mea/company/news-press-releases/`  
   RLDatix news and press releases page. citeturn11search115

---

# Section 2: Full Detailed App Review

## Executive Summary

The strongest release-source ecosystems found are **Qualtrics, Smartsheet, OneSpan, Deque Axe, Diligent Boards, and FileTrail** because each exposes public, vendor-maintained release notes or product update repositories with current and historical information. citeturn13search131turn15search157turn10search96turn6search70turn8search72turn16search171

The next strongest group is **Coda/Superhuman Docs and CyberGrants/Bonterra**, both of which expose strong public release or product-update feeds, though their structures are more mixed between product pages, community updates, and vendor documentation. citeturn3search25turn5search48turn5search49

**Planview PPM Pro and RLDatix Optimus** are high-value but require more careful monitoring because some official release sources appear customer-gated or indirectly accessible through status pages, support portals, indexed PDFs, or S3-hosted artifacts. citeturn2search13turn12search122turn12search126

Lower-confidence sources include **Convey, Apex-Lease Harbor, IQ AutoScan, KMS Lighthouse, and RedFlag**, where direct public release-note repositories were not found, although some vendors expose useful fallback signals such as news posts, login-page version numbers, mobile app updates, or marketplace listings. citeturn4search38turn9search84turn14search153turn17search186

---

## Consolidated Quality Ranking

| Quality | Applications |
|---|---|
| Excellent | Qualtrics, Smartsheet, OneSpan, Deque Axe, Diligent Boards, FileTrail |
| Very High | Coda, CyberGrants |
| High | PPM Pro, Optimus / RLDatix |
| Medium-High | RedFlag |
| Medium | IQ AutoScan, KMS Lighthouse |
| Low | Convey, Apex-Lease Harbor |

---

## IQ AutoScan

**Vendor:** Abrigo  
**Quality:** Medium

IQ AutoScan appears to be related to Abrigo’s financial crime and sanctions-screening product family, and Abrigo now markets similar capability as **Abrigo Intelligent Scan**. citeturn1search2turn1search8

### Endpoints Found

1. `https://www.iqautoscan3.com/`  
   IQ AutoScan login portal. No public release notes were visible. citeturn1search1

2. `https://sso.iqautoscan3.com/Account/Login`  
   IQ AutoScan SSO portal. No public release notes were visible. citeturn1search6

3. `https://www.abrigo.com/software/bsa-aml-and-fraud/bam/intelligent-scan/`  
   Abrigo Intelligent Scan marketing page for sanctions and watchlist screening. citeturn1search2

4. `https://www.abrigo.com/company/news/`  
   Abrigo company news page with major product announcements and company updates. citeturn1search7

### Assessment

No public changelog or release-note repository was found for IQ AutoScan. The best public monitoring source is Abrigo’s company news page, while detailed release communications likely require customer access. citeturn1search3turn1search7

---

## PPM Pro

**Vendor:** Planview Delaware, Inc.  
**Quality:** High

Planview PPM Pro is Planview’s project portfolio management platform, formerly Innotas. citeturn2search16

### Endpoints Found

1. `https://success.planview.com/Planview_PPM_Pro/Release_Information/New_Features_and_Release_Notes/`  
   Official release-note path referenced by Planview release announcements and status-page notices. Access may require customer permissions. citeturn2search12turn2search13

2. `https://community.planview.com/ppm-pro-70`  
   PPM Pro community section with product discussions and release-related topics. citeturn2search11

3. `https://community.planview.com/learn-and-share-72`  
   Community area containing PPM Pro release announcements and links to official release notes. citeturn2search12

4. `https://status.planview.com/issues/699710cfa877245b6cb0eca2`  
   PPM Pro February 2026 release deployment notice. citeturn2search13

5. `https://status.planview.com/issues/6a17022323140279f5a12447`  
   PPM Pro May 2026 release update notice. citeturn2search22

6. `https://community.planview.com/product-updates`  
   Planview Product Updates page. citeturn2search21

### Assessment

PPM Pro has a high-quality release ecosystem, but automation may need to monitor the status page and community posts if the Success Center release documentation requires authentication. citeturn2search12turn2search13turn2search22

---

## Coda

**Vendor:** Coda Project, Inc.  
**Quality:** Very High

Coda has transitioned into **Superhuman Docs**, and existing Coda links redirect to the new Superhuman Docs experience. citeturn3search30turn3search25

### Endpoints Found

1. `https://coda.io/product/whats-new`  
   Official Coda “What’s New” release page with monthly updates. citeturn3search25

2. `https://help.superhuman.com/hc/en-us/articles/46210093285773-What-s-changing-Coda-becomes-Superhuman-Docs`  
   Official Coda to Superhuman Docs transition documentation. citeturn3search30

3. `https://help.coda.io/hc/en-us/articles/39555750800397-Coda-s-2025-UI-refresh`  
   Coda UI refresh documentation. citeturn3search31

4. `https://releasebot.io/updates/coda`  
   Third-party release aggregation feed. citeturn3search26

5. `https://releases.sh/superhuman/coda`  
   Third-party release and app-version timeline. citeturn3search28

### Assessment

Coda is a very strong candidate for public release monitoring. Primary monitoring should use the official “What’s New” page, with Superhuman Help Center content used during the product transition period. citeturn3search25turn3search30

---

## Convey

**Vendor:** Association of American Medical Colleges  
**Quality:** Low

Convey is AAMC’s centralized disclosure management platform for financial interest and relationship disclosures. citeturn4search37turn4search44

### Endpoints Found

1. `https://www.convey.org/`  
   Product home page. citeturn4search37

2. `https://convey.aamc.org/`  
   Login portal exposing build/version string `20.7.1-20260713.165146`. citeturn4search38

3. `https://www.convey.org/about`  
   Product information page. citeturn4search44

4. `https://www.convey.org/faq`  
   FAQ page. citeturn4search45

5. `https://www.aamc.org/news/convey-new-system-simplify-process-disclosing-financial-interests`  
   Historical AAMC article about Convey. citeturn4search39

### Assessment

No public release-note endpoint was found. The most useful public signal is the version/build string visible on the login page. citeturn4search38turn4search43

---

## CyberGrants

**Vendor:** Bonterra  
**Quality:** Very High

CyberGrants is now part of the Bonterra product portfolio and marketed as Bonterra CyberGrants. citeturn5search46turn5search54

### Endpoints Found

1. `https://bonterra.zendesk.com/hc/en-us/sections/40326415973399-Release-Notes`  
   Bonterra release notes repository with release archives. citeturn5search48

2. `https://community.bonterratech.com/product-updates`  
   Bonterra product updates community with product filtering. citeturn5search49

3. `https://www.bonterratech.com/product/cybergrants`  
   CyberGrants product page. citeturn5search46

4. `https://trustcenter.bonterratech.com/`  
   Bonterra Trust Center for security, compliance, privacy, and AI governance information. citeturn5search52

### Assessment

Bonterra exposes strong public release-note and product-update sources. CyberGrants should be monitored through Bonterra release notes and product updates rather than legacy CyberGrants branding alone. citeturn5search48turn5search49

---

## Deque Axe

**Vendor:** Deque Systems Inc.  
**Quality:** Excellent

Deque Axe is used to verify website, web application, and mobile accessibility against ADA, WCAG, Section 508, and related digital accessibility requirements. Deque publishes detailed documentation and release notes across axe-core and Axe DevTools product lines. citeturn6search64turn6search70

### Endpoints Found

1. `https://docs.deque.com/`  
   Deque documentation hub. citeturn6search70

2. `https://docs.deque.com/axe-release-impact/4.11.0/en/release-notes/`  
   axe-core release-impact release notes. citeturn6search56

3. `https://github.com/dequelabs/axe-core/releases`  
   axe-core GitHub releases. citeturn6search58

4. `https://docs.dequelabs.com/devtools-for-web/4/en/rn-node/`  
   Axe DevTools Node.js package release notes. citeturn6search65

5. `https://docs.deque.com/devtools-for-web/4/en/devtools-4-106-1/`  
   Axe DevTools Extension release notes example. citeturn6search62

6. `https://www.deque.com/resources/topic/deque-news-updates/`  
   Deque product and company update feed. citeturn6search67

### Assessment

Deque has one of the strongest public release ecosystems found. Deque supports direct monitoring through documentation pages, GitHub releases, and product-specific release notes. citeturn6search56turn6search58turn6search70

---

## Diligent Boards

**Vendor:** Diligent Corporation  
**Quality:** Excellent

Diligent Boards is a board portal and governance platform used for board books, agendas, minutes, voting, secure communications, and governance workflows. citeturn8search80turn8search82

### Endpoints Found

1. `https://help.diligentoneplatform.com/helpdocs/boards/en-us/Content/release_notes/release-notes-boards.htm`  
   Official release notes landing page. citeturn8search72

2. `https://help.diligentoneplatform.com/helpdocs/boards/en-us/Content/release_notes/release-notes-bwa.htm`  
   Boards Web Admin release notes. citeturn8search73

3. `https://connect.diligent.com/s/productupdates-boards?language=en_US`  
   Boards product updates page. citeturn8search74

4. `https://connect.diligent.com/s/topic/0TO6T000001Z3LKWA0/release-notes?language=en_US`  
   Diligent Connect release notes topic. citeturn8search83

5. `https://www.diligent.com/resources/blog/ai-innovations-board-prep-entity-workflows`  
   Diligent Boards and Entities update blog. citeturn8search75

### Assessment

Diligent Boards has excellent release visibility with a dedicated release-note system and detailed product-specific release pages. citeturn8search72turn8search73

---

## Apex-Lease Harbor

**Vendor:** Lease Harbor LLC  
**Quality:** Low

Lease Harbor is a lease administration, lease accounting, and lease workflow platform. citeturn9search85turn9search89

### Endpoints Found

1. `https://apex.leaseharbor.com/`  
   Apex-Lease Harbor login portal. citeturn9search84

2. `https://www.leaseharbor.com/`  
   Corporate/product website. citeturn9search85

3. `https://www.leaseharbor.com/resources`  
   Resource library with white papers and product content. citeturn9search86

4. `https://www.leaseharbor.com/system`  
   Product capability page. citeturn9search89

### Assessment

No public release notes, changelog, product update feed, or version archive was found. This remains low quality unless customer-only release communications or portal resources can be accessed. citeturn9search84turn9search85

---

## OneSpan

**Vendor:** OneSpan Canada Inc.  
**Quality:** Excellent

OneSpan exposes structured release notes across OneSpan Sign, Cloud Authentication, Identity Verification, and mobile product areas. citeturn10search96turn10search108

### Endpoints Found

1. `https://docs.onespan.com/docs/oss-release-notes`  
   OneSpan Sign release notes portal. citeturn10search96

2. `https://docs.onespan.com/docs/onespan-sign-release-notes`  
   OneSpan Sign release notes. citeturn10search97

3. `https://docs.onespan.com/sec/docs/oca-release-notes`  
   OneSpan Cloud Authentication release notes. citeturn10search108

4. `https://docs.onespan.com/docs/identity-verification-release-notes`  
   OneSpan Identity Verification release notes. citeturn10search107

5. `https://docs.onespan.com/mobile/docs/release-notes-mobile-portal-26r01-march-2026`  
   Mobile Portal release note example. citeturn10search104

6. `https://www.onespan.com/about/news-releases`  
   Corporate news releases. citeturn10search103

### Assessment

OneSpan is an excellent automated monitoring candidate because the release structure is public, product-specific, versioned, and regularly maintained. citeturn10search96turn10search97turn10search108

---

## Optimus / RLDatix

**Vendor:** Datix (USA) Inc. / RLDatix  
**Quality:** High

The application name “Optimus” may correspond to RLDatix **Optima**, but the public release findings are broader RLDatix release-source findings rather than Optimus-specific release notes. RLDatix references Optima in product vision and workforce-management material. citeturn11search119turn11search120

### Endpoints Found

1. `https://www.rldatix.com/en-nam/support/`  
   RLDatix support portal page stating users can view upcoming release notes and release materials after login. citeturn11search109turn12search128

2. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/Release_Notes/DCIQ/downloads/DCIQ.2023.R8.2_CR_release_notes.pdf`  
   Public S3-hosted DCIQ release notes PDF. citeturn12search126

3. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/6.16+New+Features+%26+Enhancements/Documentation+%26+Accessories/RL6_ReleaseNotes_6.16.pdf`  
   Public S3-hosted RL6 v6.16 release notes. citeturn12search122

4. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/6.15+New+Features+%26+Enhancements/Documentation+%26+Accessories/RL6_ReleaseNotes_6.15.pdf`  
   Public S3-hosted RL6 v6.15 release notes. citeturn12search123

5. `https://elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com/6.13+New+Features+and+Enhancements/RL6_ReleaseNotes_6.13.pdf`  
   Public S3-hosted RL6 v6.13 release notes. citeturn12search124

6. `https://www.rldatix.com/en-nam/company/news`  
   RLDatix news page. citeturn11search116

7. `https://rld.rldatix.com/en-mea/company/news-press-releases/`  
   RLDatix press release page. citeturn11search115

### Assessment

RLDatix was upgraded from medium to high because S3-hosted release-note PDFs were publicly indexed. The release ecosystem likely requires support-portal and S3/document discovery rather than monitoring a clean public release page. citeturn12search122turn12search126

---

## Qualtrics

**Vendor:** Qualtrics LLC  
**Quality:** Excellent

Qualtrics provides a strong public release-note community with weekly and monthly release notes. citeturn13search131turn13search140

### Endpoints Found

1. `https://community.qualtrics.com/product-release-notes-96`  
   Official product release notes section. citeturn13search131

2. `https://community.qualtrics.com/product-release-notes-96/weekly-product-release-notes-july-1-2026-33472`  
   Example weekly release note. citeturn13search132

3. `https://community.qualtrics.com/product-release-notes-96/monthly-product-release-notes-march-6-2025-to-april-2-2025-31881`  
   Example monthly release note. citeturn13search143

4. `https://community.qualtrics.com/product-release-notes-96/subscribe-to-product-release-notes-7699`  
   Subscription instructions. citeturn13search140

### Assessment

Qualtrics is one of the best release-monitoring candidates because it exposes frequent release updates, historical posts, product categories, and subscription functionality. citeturn13search131turn13search140

---

## RedFlag

**Vendor:** Pocketstop LLC  
**Quality:** Medium-High

RedFlag is a mass notification and emergency communication platform supporting SMS, email, voice, Teams integration, mobile app notifications, and emergency communications. citeturn14search150turn14search151

### Endpoints Found

1. `https://www.prnewswire.com/news/pocketstop/`  
   Pocketstop PR Newswire feed with RedFlag feature releases, integrations, and technology updates. citeturn14search153

2. `https://redflagalerts.com/blog/pocketstop-redflags-latest-release-adds-location-based-alerts-for-increased-safety-and-communication/`  
   RedFlag blog post for location-based alerts release. citeturn14search147

3. `https://www.prnewswire.com/news-releases/pocketstop-redflags-latest-release-adds-location-based-alerts-for-increased-safety-and-communication-301785460.html`  
   PR Newswire release for location-based alerts. citeturn14search146

4. `https://www.prnewswire.com/news-releases/pocketstop-announces-an-updated-refreshed-interface-and-navigation-to-redflag-mass-notification-making-it-even-easier-to-use-301624726.html`  
   PR Newswire release for UI refresh and navigation update. citeturn14search145

5. `https://redflagalerts.com/blog/pocketstop-announces-new-software-version-release-redflag-notification-system-10278/`  
   Historical RedFlag software version release post. citeturn14search149

6. `https://redflagalerts.com/support/`  
   Support page referencing customer knowledge portal accessible through the platform. citeturn14search156

7. `https://play.google.com/store/apps/details?id=com.companyname.PocketstopApp&hl=en-US`  
   Mobile app listing with app update information. citeturn14search152

### Assessment

RedFlag does not expose a dedicated public release-note repository, but it does publicly announce major releases and product updates. Monitoring should include PR Newswire, the RedFlag blog, and app-store version changes. citeturn14search145turn14search146turn14search153

---

## Smartsheet

**Vendor:** Smartsheet Inc.  
**Quality:** Excellent

Smartsheet has a public release-news system with product releases, action-required notices, API changes, and community announcements. citeturn15search157turn15search159

### Endpoints Found

1. `https://www.smartsheet.com/content-center/product-news/release-notes/all`  
   Official release news portal. citeturn15search157

2. `https://community.smartsheet.com/en/categories/product-announcements`  
   Product announcements community. citeturn15search159

3. `https://community.smartsheet.com/discussion/69251/receive-the-latest-smartsheet-product-release-notes-on-new-capabilities-and-enhancements-by-email`  
   Release-note subscription details. citeturn15search162

4. `https://de.smartsheet.com/content-center/product-news/release-notes`  
   Localized release-news page showing Smartsheet Default, EU, and Gov categories. citeturn15search161

### Assessment

Smartsheet is an excellent release-monitoring candidate because it exposes routine product updates, API updates, infrastructure-impacting notices, and subscription options. citeturn15search157turn15search162

---

## FileTrail

**Vendor:** Freedom Solutions Group LLC / now Litera  
**Quality:** Excellent

FileTrail release notes are publicly available through Litera’s support site after FileTrail joined Litera. citeturn16search169turn16search171

### Endpoints Found

1. `https://support.litera.com/article/FileTrail-5-24-0-Release-Notes`  
   FileTrail 5.24.0 release notes. citeturn16search171

2. `https://support.litera.com/article/FileTrail-v5220-Release-Notes-537564`  
   FileTrail v5.22.0 release notes. citeturn16search165

3. `https://support.litera.com/article/FileTrail-v5-21-0-Release-Notes`  
   FileTrail v5.21.0 release notes. citeturn16search166

4. `https://support.litera.com/article/FileTrail-v5-22-7-Release-Notes`  
   FileTrail v5.22.7 release notes. citeturn16search174

5. `https://support.litera.com/article/FileTrail-Documentation-Downloads`  
   FileTrail documentation download page. citeturn16search175

6. `https://mpa.filetrail.com/DataManager/Login.aspx`  
   FileTrail login page exposing version `5.22.9.1`. citeturn16search167

### Assessment

FileTrail is an excellent release-monitoring candidate, with current release notes, historical release notes, documentation downloads, and visible version numbers on at least one login endpoint. citeturn16search171turn16search175

---

## KMS Lighthouse

**Vendor:** KMS Lighthouse  
**Quality:** Medium

KMS Lighthouse is an AI-powered enterprise knowledge management platform used for contact centers, agent assist, employee knowledge management, and self-service search. citeturn17search186turn17search185

### Endpoints Found

1. `https://kmslh.com/resources/`  
   Knowledge Center with blogs, webinars, guides, reports, videos, news, and events. citeturn17search182

2. `https://www.prnewswire.com/news/kms-lighthouse/`  
   PR Newswire feed for KMS Lighthouse. citeturn17search179

3. `https://store.servicenow.com/store/app/95d2a0171ba6e21025fe65b2604bcb69`  
   ServiceNow Store listing exposing version `2.0.7`. citeturn17search186

4. `https://marketplace.atlassian.com/vendors/677047331/kms-lighthouse-enterprise-knowledge-management`  
   Atlassian Marketplace vendor listing. citeturn17search187

5. `https://api-cdn.mypurecloud.com/uploads/v1/publicassets/integrations/appfoundry/listing-media/d8aaab49-a762-439e-8bf0-74055236a614/4eebd5b4-7922-485f-bf96-a949fcb6182b.marketingurl_d54aa828.en-us.pdf`  
   Public integration PDF describing KMS Lighthouse capabilities. citeturn17search185

### Assessment

No public release-note repository was found. However, the ServiceNow Store and Atlassian Marketplace listings provide version-monitoring opportunities for integrations. citeturn17search186turn17search187

---

# Recommended Monitoring Strategy

## Primary Automated Targets

Use these first because each target is public, direct, and release-note specific:

- Qualtrics Product Release Notes: `https://community.qualtrics.com/product-release-notes-96` citeturn13search131
- Smartsheet Release News: `https://www.smartsheet.com/content-center/product-news/release-notes/all` citeturn15search157
- OneSpan Release Notes: `https://docs.onespan.com/docs/oss-release-notes` citeturn10search96
- Deque Docs / GitHub Releases: `https://docs.deque.com/` and `https://github.com/dequelabs/axe-core/releases` citeturn6search70turn6search58
- Diligent Boards Release Notes: `https://help.diligentoneplatform.com/helpdocs/boards/en-us/Content/release_notes/release-notes-boards.htm` citeturn8search72
- FileTrail Release Notes: `https://support.litera.com/article/FileTrail-5-24-0-Release-Notes` citeturn16search171

## Secondary Automated Targets

Use these for vendors with strong but less uniform release structures:

- Coda What’s New: `https://coda.io/product/whats-new` citeturn3search25
- Bonterra Release Notes: `https://bonterra.zendesk.com/hc/en-us/sections/40326415973399-Release-Notes` citeturn5search48
- Planview Community / Status: `https://community.planview.com/ppm-pro-70` and `https://status.planview.com` citeturn2search11turn2search13
- RLDatix Support + S3 PDFs: `https://www.rldatix.com/en-nam/support/` and indexed `elasticbeanstalk-us-east-1-420057813367.s3.amazonaws.com` PDFs. citeturn12search128turn12search122turn12search126

## Follow-Up Targets

These require deeper research, authenticated access, or lower-confidence monitoring:

- Convey login page version monitoring: `https://convey.aamc.org/` citeturn4search38
- Lease Harbor login and resources: `https://apex.leaseharbor.com/` and `https://www.leaseharbor.com/resources` citeturn9search84turn9search86
- RedFlag blog and PR Newswire feed: `https://www.prnewswire.com/news/pocketstop/` and `https://redflagalerts.com/blog/` citeturn14search153turn14search147
- KMS Lighthouse marketplace listings: ServiceNow Store and Atlassian Marketplace. citeturn17search186turn17search187

---

# Final Notes for Agents

- Prefer **official release-note endpoints** over PR/news feeds.
- Prefer **vendor documentation portals** over third-party aggregators.
- Use third-party aggregators only as backup detection or cross-check sources.
- For apps rated **Low** or **Medium**, perform a second-pass search for:
  - `/release-notes`
  - `/releases`
  - `/whats-new`
  - `/hc/en-us/search?query=release%20notes`
  - `site:vendor-domain.com "release notes"`
  - `site:s3.amazonaws.com vendor-name "release notes" filetype:pdf`
  - `site:*.zendesk.com vendor-name "release notes"`
  - `site:*.freshdesk.com vendor-name "release notes"`
  - marketplace app versions
  - login-page build strings
- Avoid broad bucket enumeration or unauthenticated probing beyond public search-indexed URLs unless there is explicit authorization.
