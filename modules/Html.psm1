Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Minimal HTML helpers for the platform-automation framework.

.DESCRIPTION
    Html.psm1 currently exposes a single function - ConvertFrom-
    HtmlToText - that turns a chunk of HTML into a short plaintext
    excerpt suitable for inclusion in a Markdown report. It is
    intentionally not a full HTML parser; it just strips tags, decodes
    the handful of entities Zendesk uses, and collapses whitespace.

    When the future HtmlCollector is implemented it will use this
    function (and may grow helpers for selectors / attribute
    extraction). For now the module exists so the rest of the
    framework can call ConvertFrom-HtmlToText without conditional
    imports.
#>

function ConvertFrom-HtmlToText {
    <#
    .SYNOPSIS
        Convert a snippet of HTML into plaintext.
    .DESCRIPTION
        Strips tags, decodes the common named and numeric entities
        Zendesk produces, and collapses runs of whitespace into a
        single space. The optional -MaxLength truncates the result
        with a trailing ellipsis if it would be longer.
    .PARAMETER Html
        HTML input.
    .PARAMETER MaxLength
        If positive, the returned string is truncated to at most
        this many characters with a trailing '...'.
    .EXAMPLE
        ConvertFrom-HtmlToText '<p>Hello&nbsp;<b>world</b></p>'
        # -> 'Hello world'
    .EXAMPLE
        ConvertFrom-HtmlToText -Html $body -MaxLength 200
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Html,

        [ValidateRange(0, 10000)]
        [int]$MaxLength = 0
    )

    if ([string]::IsNullOrEmpty($Html)) { return '' }

    $text = [System.Net.WebUtility]::HtmlDecode($Html)

    $text = [regex]::Replace($text, '<[^>]+>', ' ')

    $text = $text -replace '\s+', ' '
    $text = $text.Trim()

    if ($MaxLength -gt 0 -and $text.Length -gt $MaxLength) {
        $text = $text.Substring(0, [Math]::Max(0, $MaxLength - 3)).TrimEnd() + '...'
    }
    return $text
}

function ConvertTo-HtmlDocument {
    <#
    .SYNOPSIS
        Wrap a raw HTML fragment in a complete, styled HTML5 document.
    .DESCRIPTION
        The Zendesk API returns article bodies as HTML fragments (no
        <html>, no <head>, no <body>, no stylesheet). When saved
        as-is and opened in a browser, they render as unstyled text.
        This function wraps the fragment in a minimal but readable
        document so the captured file looks like a real article
        when opened.
    .PARAMETER Body
        The raw HTML fragment to wrap.
    .PARAMETER Title
        Document <title> and the visible header. Defaults to the
        article id if not provided.
    .PARAMETER SourceUrl
        Optional URL of the source article; rendered as a footer
        link for traceability.
    .PARAMETER DetectedAt
        Optional ISO 8601 timestamp; rendered in the footer.
    .EXAMPLE
        ConvertTo-HtmlDocument -Body $raw -Title $title -SourceUrl $url -DetectedAt $now
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Body,

        [string]$Title = 'Vendor release capture',

        [string]$SourceUrl,

        [string]$DetectedAt
    )

    $safeTitle = if ([string]::IsNullOrWhiteSpace($Title)) { 'Vendor release capture' } else { $Title }
    $safeTitleEsc = [System.Net.WebUtility]::HtmlEncode($safeTitle)
    $footer = ''
    if ($SourceUrl -or $DetectedAt) {
        $footerParts = @()
        if ($DetectedAt) { $footerParts += ("captured at " + ($DetectedAt -replace '<', '&lt;') ) }
        if ($SourceUrl) { $footerParts += ("<a href=""$([System.Net.WebUtility]::HtmlEncode($SourceUrl))"">source</a>") }
        $footer = "<footer style=""margin-top:32px;padding-top:16px;border-top:1px solid #ddd;color:#666;font-size:12px;"">" + ($footerParts -join ' &middot; ') + '</footer>'
    }

    $css = @'
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  max-width: 820px;
  margin: 32px auto;
  padding: 0 24px;
  line-height: 1.6;
  color: #1f1f1f;
  background: #f6f7f8;
}
article {
  background: #ffffff;
  padding: 32px 40px;
  border-radius: 6px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}
h1, h2, h3, h4 { color: #0b3d91; line-height: 1.25; }
h1 { font-size: 24px; margin-top: 0; }
h2 { font-size: 20px; }
h3 { font-size: 16px; }
p { margin: 1em 0; }
a { color: #0b3d91; text-decoration: none; border-bottom: 1px solid rgba(11, 61, 145, 0.3); }
a:hover { border-bottom-color: #0b3d91; }
strong { color: #111; }
ul, ol { padding-left: 1.5em; }
li { margin: 0.25em 0; }
img { max-width: 100%; height: auto; }
code { background: #f4f4f4; padding: 1px 4px; border-radius: 3px; font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace; font-size: 0.9em; }
pre { background: #f4f4f4; padding: 12px 16px; border-radius: 4px; overflow-x: auto; }
blockquote { margin: 1em 0; padding: 0.5em 1em; border-left: 3px solid #0b3d91; color: #444; background: #fafafa; }
header.doc { margin-bottom: 24px; padding-bottom: 12px; border-bottom: 1px solid #ddd; }
header.doc .meta { color: #666; font-size: 13px; margin-top: 4px; }
'@

    $bodyEsc = if ([string]::IsNullOrEmpty($Body)) { '<p><em>(empty body)</em></p>' } else { $Body }

    return @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$safeTitleEsc</title>
<style>
$css
</style>
</head>
<body>
<article>
<header class="doc">
<h1>$safeTitleEsc</h1>
</header>
$bodyEsc
$footer
</article>
</body>
</html>
"@
}

Export-ModuleMember -Function ConvertFrom-HtmlToText, ConvertTo-HtmlDocument
