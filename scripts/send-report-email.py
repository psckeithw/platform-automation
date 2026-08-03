#!/usr/bin/env python3
"""
send-report-email.py - send the VendorReport.md artifact to a recipient list
via Gmail API using the OAuth refresh token in the Hearbeat/google/.env file.

This is the "quickest path" distribution channel: a thin wrapper over
the Gmail API that:
  1. loads the GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET / GMAIL_REFRESH_TOKEN
     from the env file (default: /mnt/shared/code/Hearbeat/google/.env);
  2. builds a MIMEText email with the report body;
  3. sends it to the recipient list via users.messages.send.

Usage:
  pwsh -File scripts/send-report-email.py \
      --report /path/to/VendorReport.md \
      --to "alice@example.com,bob@example.com" \
      --subject "RLDatix release notes - 2026-08-03"

  # Or, after a pipeline run, pass the run id and the script will
  # download the artifact from Azure DevOps:
  ADO_PAT=... pwsh -File scripts/send-report-email.py \
      --run 202 \
      --to "alice@example.com" \
      --subject "RLDatix release notes - run 202"

  # As a pipeline step (post-run): same flags. Wire into vendor-monitor.yml
  # after the artifact-publish step.

Environment:
  ADO_PAT    required when --run is used; passed through to the ADO REST
             artifact-download call.
  GMAIL_*    read from the env file (path can be overridden with --env-file).

Notes:
  - The Gmail account is the one whose refresh token is in the .env. The
    'From' address is whatever Google reports for the OAuth consent
    (typically the user's primary Gmail).
  - The email is multipart/alternative with text/plain (the raw report)
    and text/html (the same report wrapped in a minimal HTML template
    so email clients render the table). If the markdown library is not
    available, it falls back to text-only.
  - Attachments are not added in MVP; the VendorReport.md body IS the
    report. The raw HTML captures and JSON are available in the ADO
    artifact but not emailed.
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
import urllib.parse
import urllib.request
from email.message import EmailMessage
from pathlib import Path
from typing import Iterable

DEFAULT_ENV_FILE = "/mnt/shared/code/Hearbeat/google/.env"
DEFAULT_ADO_ORG = "AzureDevOpsDFW"
DEFAULT_ADO_PROJ = "Heartbeat"
GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"


def die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def load_env_file(path: str) -> dict[str, str]:
    """Parse a simple KEY=VALUE .env file. Returns a dict."""
    p = Path(path)
    if not p.exists():
        die(f"env file not found: {path}")
    out: dict[str, str] = {}
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def get_gmail_credentials(env: dict[str, str]):
    """Build OAuth2 credentials from the refresh token in env."""
    try:
        from google.oauth2.credentials import Credentials
    except ImportError as e:
        die(f"google-auth-oauthlib / google.oauth2 not installed: {e}")
    cid = env.get("GMAIL_CLIENT_ID")
    csec = env.get("GMAIL_CLIENT_SECRET")
    rtoken = env.get("GMAIL_REFRESH_TOKEN")
    if not all([cid, csec, rtoken]):
        die("missing GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET / GMAIL_REFRESH_TOKEN in env file")
    return Credentials(
        token=None,
        refresh_token=rtoken,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=cid,
        client_secret=csec,
        scopes=[GMAIL_SEND_SCOPE],
    )


def refresh_if_needed(creds) -> None:
    if creds.expired and creds.refresh_token:
        from google.auth.transport.requests import Request
        creds.refresh(Request())


def build_gmail_service(creds):
    from googleapiclient.discovery import build
    return build("gmail", "v1", credentials=creds, cache_discovery=False)


def download_artifact_via_ado(run_id: int, artifact_name: str, pat: str,
                              org: str, project: str) -> bytes:
    """Download an ADO pipeline artifact as a zip blob."""
    meta_url = (f"https://dev.azure.com/{org}/{project}/_apis/build/builds/"
                f"{run_id}/artifacts?artifactName={artifact_name}&api-version=7.0")
    req = urllib.request.Request(meta_url, headers={"Accept": "application/json"})
    basic = base64.b64encode(f":{pat}".encode()).decode()
    req.add_header("Authorization", f"Basic {basic}")
    with urllib.request.urlopen(req, timeout=30) as r:
        meta = json.loads(r.read())
    download_url = meta["resource"]["downloadUrl"]
    print(f"  downloading {artifact_name} from run {run_id} ({len(download_url)} byte url)...")
    req = urllib.request.Request(download_url, headers={"Authorization": f"Basic {basic}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def extract_md_from_zip(zip_bytes: bytes, name: str = "VendorReport.md") -> str:
    """Extract VendorReport.md from the artifact zip. Stdlib zipfile."""
    import io
    import zipfile
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        for n in zf.namelist():
            if n.endswith(name):
                return zf.read(n).decode("utf-8")
    die(f"{name} not found in artifact zip")


def render_md_to_html(md_text: str) -> str:
    """Convert Markdown to a minimal HTML email body. Falls back to
    a <pre>-wrapped plaintext rendering if the markdown library is
    not installed."""
    try:
        import markdown  # type: ignore
        body = markdown.markdown(
            md_text,
            extensions=["tables", "fenced_code"],
            output_format="html5",
        )
    except ImportError:
        # Minimal fallback: wrap the text in <pre> so the report is
        # at least readable. Install 'markdown' for a proper table render.
        body = "<pre style=\"font-family: monospace; white-space: pre-wrap;\">" + \
               md_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") + \
               "</pre>"
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Vendor Release Report</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
       max-width: 960px; margin: 24px auto; padding: 0 16px; color: #222; }}
h1, h2 {{ color: #0b3d91; }}
table {{ border-collapse: collapse; width: 100%; font-size: 13px; }}
th, td {{ border: 1px solid #d0d0d0; padding: 4px 8px; text-align: left; vertical-align: top; }}
th {{ background: #f4f4f4; }}
code {{ background: #f4f4f4; padding: 1px 4px; border-radius: 3px; }}
</style></head>
<body>
{body}
<hr>
<p style="color:#666;font-size:12px;">Sent by platform-automation / send-report-email.py
(the markdown 'tables' extension requires the <code>markdown</code> Python
package for the HTML table; this fallback renders as a code block).</p>
</body></html>
"""


def send_message(service, sender: str, to_addrs: Iterable[str],
                 subject: str, text_body: str, html_body: str) -> dict:
    """Build a multipart/alternative email and send via users.messages.send."""
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = ", ".join(to_addrs)
    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
    body = {"raw": raw}
    return service.users().messages().send(userId="me", body=body).execute()


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--report", help="Path to a VendorReport.md file on disk.")
    src.add_argument("--run", type=int, help="Azure DevOps pipeline run id "
                   "(requires ADO_PAT env var and --artifact, default 'platform-automation-output').")
    p.add_argument("--artifact", default="platform-automation-output",
                   help="ADO artifact name when --run is used (default: platform-automation-output).")
    p.add_argument("--to", required=True, help="Comma-separated recipient list.")
    p.add_argument("--subject", required=True, help="Email subject line.")
    p.add_argument("--from", dest="from_addr", default=None,
                   help="Override the From: address (default: 'me' = the OAuth account).")
    p.add_argument("--env-file", default=DEFAULT_ENV_FILE,
                   help=f"Path to the .env file with Gmail creds (default: {DEFAULT_ENV_FILE}).")
    p.add_argument("--ado-org", default=DEFAULT_ADO_ORG)
    p.add_argument("--ado-proj", default=DEFAULT_ADO_PROJ)
    p.add_argument("--dry-run", action="store_true",
                   help="Build the message but don't send. Prints headers and sizes.")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    # 1. Get the report body
    if args.report:
        md_path = Path(args.report)
        if not md_path.exists():
            die(f"report file not found: {args.report}")
        md_text = md_path.read_text(encoding="utf-8")
        print(f"  loaded report from {args.report} ({len(md_text)} bytes)")
    else:
        pat = os.environ.get("ADO_PAT")
        if not pat:
            die("--run requires ADO_PAT env var")
        zip_bytes = download_artifact_via_ado(
            args.run, args.artifact, pat, args.ado_org, args.ado_proj)
        md_text = extract_md_from_zip(zip_bytes, "VendorReport.md")
        print(f"  extracted VendorReport.md from run {args.run} artifact ({len(md_text)} bytes)")

    # 2. Build HTML
    html_body = render_md_to_html(md_text)
    print(f"  rendered HTML body ({len(html_body)} bytes)")

    # 3. Load Gmail creds
    env = load_env_file(args.env_file)
    creds = get_gmail_credentials(env)
    refresh_if_needed(creds)
    print(f"  Gmail credentials ok (scopes={[s for s in (creds.scopes or [])]})")

    # 4. Validate recipient list
    to_list = [a.strip() for a in args.to.split(",") if a.strip()]
    if not to_list:
        die("--to requires at least one address")
    for a in to_list:
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", a):
            die(f"invalid email address: {a}")

    # 5. Dry-run or send
    if args.dry_run:
        print(f"  DRY RUN: would send subject='{args.subject}' to={to_list} "
              f"from={args.from_addr or '(me)'} text={len(md_text)}b html={len(html_body)}b")
        return 0

    service = build_gmail_service(creds)
    sender = args.from_addr or "me"
    result = send_message(service, sender, to_list, args.subject, md_text, html_body)
    print(f"  sent: id={result.get('id')} threadId={result.get('threadId')}")
    print(f"  DONE: subject='{args.subject}' to={to_list}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
