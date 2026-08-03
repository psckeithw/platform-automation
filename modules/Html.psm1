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

Export-ModuleMember -Function ConvertFrom-HtmlToText
