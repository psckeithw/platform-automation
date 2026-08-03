# Platform-Automation

## Document Summary
This plan is intentionally written as an architecture and implementation brief rather than a detailed technical specification. It should give your architect enough direction to scaffold the repository, define the task framework, and break the work into implementation stories without constraining future enhancements.

## Phase 1 MVP – Architecture & Implementation Plan

### Project Overview

The purpose of the **platform-automation** repository is to provide a centralized automation framework for operational and administrative tasks executed through Azure DevOps Pipelines.

This repository is **not** intended to solve a single problem such as vendor monitoring. Instead, it establishes a common framework for hosting reusable PowerShell-based automation tasks that can be scheduled, manually executed, or eventually migrated into Azure Functions.

The first deliverable (MVP) will implement **Vendor Release Monitoring** as a proof of concept while establishing reusable architecture for future automation.

---

# Goals

## Primary Goals

* Create a reusable automation framework.
* Standardize PowerShell execution from Azure DevOps Pipelines.
* Separate orchestration from business logic.
* Enable both scheduled and manual execution.
* Produce consistent logging and reporting.
* Minimize infrastructure requirements.
* Keep the solution source-controlled and extensible.

## Non-Goals (Phase 1)

* Azure Functions
* Durable Functions
* MCP integration
* AI summarization
* Database storage
* Browser automation (unless absolutely required)
* Teams notifications
* Workflow automation

---

# Repository Structure

```text
platform-automation/

├── azure-pipelines/
│   ├── vendor-monitor.yml
│   ├── graph-automation.yml
│   ├── ado-reporting.yml
│   └── maintenance.yml
│
├── config/
│   ├── vendors.json
│   ├── environments.json
│   └── settings.json
│
├── modules/
│   ├── Common.psm1
│   ├── Logging.psm1
│   ├── Html.psm1
│   ├── Graph.psm1
│   └── Utilities.psm1
│
├── tasks/
│   ├── VendorMonitor/
│   │   ├── Run.ps1
│   │   ├── RLDatix.ps1
│   │   ├── Microsoft.ps1
│   │   └── Atlassian.ps1
│   │
│   ├── UserTermination/
│   ├── GraphAutomation/
│   ├── AzureDevOps/
│   └── ServiceNow/
│
├── output/
│
└── README.md
```

---

# Architectural Principles

## 1. Pipeline = Orchestration

Azure DevOps Pipelines are responsible for:

* scheduling
* parameter handling
* artifact publishing
* logging
* execution

Pipelines should **not** contain business logic.

---

## 2. PowerShell = Business Logic

Each task encapsulates its own implementation.

Examples:

* Vendor Monitoring
* Microsoft Graph Administration
* Azure DevOps Reporting
* ServiceNow Utilities
* User Lifecycle Automation

Each task must be independently executable.

Example:

```powershell
.\tasks\VendorMonitor\Run.ps1
```

The same entry point should be callable from Azure DevOps.

---

## 3. Shared Modules

Reusable functionality belongs in `/modules`.

Examples:

* logging
* retry logic
* HTML parsing
* HTTP requests
* authentication
* JSON helpers
* output formatting

No duplicate helper code across tasks.

---

## 4. Configuration-Driven

Avoid hardcoded URLs and settings.

Configuration should be externalized.

Example:

```json
{
  "Vendor": "RLDatix",
  "Collector": "HtmlCollector",
  "Url": "https://...",
  "Enabled": true
}
```

Adding a vendor should require little or no pipeline modification.

---

# Initial MVP Task

## Vendor Release Monitor

Purpose:

Detect newly published vendor release information.

Initial supported source:

* RLDatix Release Notes

Future sources:

* Azure DevOps
* Atlassian
* ServiceNow
* Microsoft 365
* Additional enterprise SaaS vendors

---

## Phase 1 Collection Strategy

Priority order:

1. Official API
2. RSS/Atom Feed
3. Public HTML Page
4. Browser Automation (future)
5. AI-assisted extraction (future)

---

# Vendor Monitor Output

Each execution should produce structured output containing:

* Vendor
* Product
* Detection Timestamp
* Published Date
* Title
* Source URL
* Change Detected (Yes/No)

Example:

```text
Vendor: RLDatix

Published:
2026-08-02

Title:
Release Notes - August 2026

Status:
NEW

URL:
https://...

Detected:
2026-08-03 06:00 UTC
```

---

# Artifact Generation

Every execution should publish artifacts including:

* Summary report (Markdown)
* Structured JSON output
* Raw HTML capture (optional but recommended)

Example:

```text
output/

VendorReport.md
VendorReport.json
RLDatix.html
ExecutionLog.txt
```

Capturing the original source improves traceability and troubleshooting.

---

# Pipeline Design

Initial pipeline characteristics:

* Scheduled execution
* Manual execution
* Parameter support
* Publish artifacts
* Fail independently by task
* Continue processing remaining vendors when practical

Future enhancements may include reusable YAML templates to reduce duplication.

---

# Logging Standards

Each task should log:

* Start time
* End time
* Duration
* Vendor
* Source URL
* HTTP status
* Errors
* Summary

Logs should be readable both in Azure DevOps and as downloadable artifacts.

---

# Extensibility

The framework should support future task categories without architectural changes.

Examples:

* Vendor Monitoring
* Azure DevOps Administration
* Microsoft Graph Administration
* ServiceNow Automation
* Health Checks
* License Reporting
* Compliance Reporting
* Scheduled Maintenance
* Internal Operational Reporting

---

# Future Roadmap (Out of Scope for MVP)

Potential future evolution includes:

* Azure Function hosting
* Shared C# collector libraries
* Persistent storage
* MCP server exposing automation data
* AI-generated summaries
* Teams notifications
* Email digests
* Dashboard UI
* Searchable historical data

These capabilities should be considered during architectural design but are explicitly deferred until after the Phase 1 MVP is complete.

---

# Success Criteria

The MVP will be considered successful when:

* A scheduled Azure DevOps Pipeline executes without manual intervention.
* Vendor monitoring logic is isolated from pipeline orchestration.
* RLDatix release information is collected successfully.
* A report artifact is generated and published.
* The framework allows additional automation tasks to be added using the same structure with minimal effort.
* Repository structure, module organization, and coding standards are documented for future contributors.
