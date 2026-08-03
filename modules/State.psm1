Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Persistence and change-detection boundary for the
    platform-automation framework.

.DESCRIPTION
    State.psm1 is the single seam between the rest of the framework
    and the on-disk state format. Everything that reads or writes
    state/vendor-state.json goes through this module so that:

      * the on-disk shape can change without touching collectors or
        Run.ps1;
      * a future Azure Blob (or DB) backend is a drop-in replacement
        for these functions.

    The detection algorithm is deliberately collector-agnostic: the
    record key is the item's stable Id when present, else a SHA-256
    hash of the item's normalized content. The content hash that
    drives CHANGED vs UNCHANGED is computed from
    "Vendor|Product|Title|PublishedDate|SourceUrl".

    Cold start (no prior state) is treated as a baseline: every item
    is stored and tagged BASELINE; nothing is reported as NEW. This
    avoids the day-one alert storm described in plan §Q1.
#>

function Get-StateFilePath {
    <#
    .SYNOPSIS
        Resolve the on-disk path of the vendor-state file.
    .DESCRIPTION
        -StatePath is treated as a directory; the state file is
        always <StatePath>/vendor-state.json. Returns the resolved
        absolute path.
    .PARAMETER StatePath
        Directory holding the state file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath
    )
    if (-not (Test-Path -LiteralPath $StatePath -PathType Container)) {
        New-Item -ItemType Directory -Path $StatePath -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $StatePath).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar + 'vendor-state.json'
}

function Get-PreviousState {
    <#
    .SYNOPSIS
        Read the previous vendor state from disk.
    .DESCRIPTION
        Returns the keyed map stored in vendor-state.json. If the
        file does not exist (cold start, first run after the branch
        was created, or local-dev clone), returns an empty hashtable.
        No exceptions are thrown on a missing file.
    .PARAMETER StatePath
        Directory containing the state file.
    .EXAMPLE
        $prev = Get-PreviousState -StatePath ./state
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath
    )

    $file = Get-StateFilePath -StatePath $StatePath
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        return @{}
    }
    try {
        $raw = Get-Content -LiteralPath $file -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Get-PreviousState: '$file' is unreadable or invalid JSON. $($_.Exception.Message)"
    }
    if ($null -eq $obj) { return @{} }
    $map = @{}
    foreach ($p in $obj.PSObject.Properties) {
        $map[$p.Name] = $p.Value
    }
    return $map
}

function Get-ContentHash {
    <#
    .SYNOPSIS
        Compute the SHA-256 hash of a normalized item's content.
    .DESCRIPTION
        The hash covers the five fields that define a release from
        the operator's perspective: Vendor, Product, Title,
        PublishedDate, SourceUrl. A change to any of these is a
        CHANGED event; anything else (body text, internal IDs) is
        intentionally ignored.
    .PARAMETER Item
        Normalized record with Vendor/Product/Title/PublishedDate/
        SourceUrl properties.
    .OUTPUTS
        Lower-case hex SHA-256 string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Item
    )
    $vendor  = [string]$Item.Vendor
    $product = [string]$Item.Product
    $title   = [string]$Item.Title
    $date    = [string]$Item.PublishedDate
    $url     = [string]$Item.SourceUrl
    $payload = "$vendor|$product|$title|$date|$url"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $hash  = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Get-RecordKey {
    <#
    .SYNOPSIS
        Return the stable record key for a normalized item.
    .DESCRIPTION
        If the item carries a non-empty Id (e.g. the Zendesk article
        id), that is the key. Otherwise the key is the SHA-256 of
        the item's current content. The function returns both the
        key and the content hash so callers can use them without a
        second pass.
    .PARAMETER Item
    .OUTPUTS
        [pscustomobject]@{ Key; Hash }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item
    )
    $hash = Get-ContentHash -Item $Item
    $id = "$($Item.Id)"
    if ([string]::IsNullOrWhiteSpace($id)) {
        return [pscustomobject]@{ Key = "hash:$hash"; Hash = $hash }
    }
    return [pscustomobject]@{ Key = "id:$id"; Hash = $hash }
}

function Compare-ReleaseState {
    <#
    .SYNOPSIS
        Tag each item with NEW / CHANGED / UNCHANGED / BASELINE and
        produce the new state map.
    .DESCRIPTION
        Walks -Items once. For each item it computes the key and the
        current content hash, then compares against -Previous. The
        resulting state map covers every key seen in this run.

        Status meanings:
          * BASELINE  - previous state was empty; this is the first
            time we are recording the item. Not reported as NEW.
          * NEW       - key was not in previous.
          * CHANGED   - key was in previous but the content hash
            differs.
          * UNCHANGED - key was in previous and the hash matches.

        The function never throws on a single bad item; bad items
        are tagged as ERROR and excluded from the new state.

    .PARAMETER Previous
        Map returned by Get-PreviousState (may be empty).
    .PARAMETER Items
        Array of normalized records from a collector.
    .PARAMETER Now
        Override for the current UTC timestamp (used in tests).
    .OUTPUTS
        [pscustomobject]@{
            Items      = items with .ChangeStatus appended
            NewState   = the keyed map to feed into Save-CurrentState
            IsBaseline = $true if Previous was empty
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable]$Previous,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [datetime]$Now = (Get-Date).ToUniversalTime()
    )

    $isBaseline = ($Previous.Count -eq 0)
    $newState   = @{}
    $tagged     = New-Object System.Collections.Generic.List[object]

    foreach ($item in @($Items)) {
        try {
            $keyInfo = Get-RecordKey -Item $item
        }
        catch {
            $tagged.Add(($item | Select-Object *, @{ Name='ChangeStatus'; Expression={ 'ERROR' } }))
            continue
        }

        $status = if ($isBaseline) {
            'BASELINE'
        }
        elseif (-not $Previous.ContainsKey($keyInfo.Key)) {
            'NEW'
        }
        elseif ("$($Previous[$keyInfo.Key].hash)" -ne $keyInfo.Hash) {
            'CHANGED'
        }
        else {
            'UNCHANGED'
        }

        $firstSeen = if ($Previous.ContainsKey($keyInfo.Key) -and $Previous[$keyInfo.Key].firstSeen) {
            [string]$Previous[$keyInfo.Key].firstSeen
        } else {
            $Now.ToString('yyyy-MM-ddTHH:mm:ssZ')
        }

        $newState[$keyInfo.Key] = [ordered]@{
            title     = [string]$item.Title
            hash      = $keyInfo.Hash
            firstSeen = $firstSeen
            sourceUrl = [string]$item.SourceUrl
        }

        $tagged.Add(($item | Select-Object *, @{ Name='ChangeStatus'; Expression={ $status } }))
    }

    return [pscustomobject]@{
        Items      = $tagged.ToArray()
        NewState   = $newState
        IsBaseline = $isBaseline
    }
}

function Save-CurrentState {
    <#
    .SYNOPSIS
        Persist the new state map to vendor-state.json.
    .DESCRIPTION
        Writes atomically: a sibling .tmp file is written first and
        then renamed over the target. Returns the resolved path.
        The directory is created if missing.
    .PARAMETER StatePath
        Directory in which vendor-state.json is written.
    .PARAMETER State
        The keyed map produced by Compare-ReleaseState.
    .PARAMETER Now
        Optional override (used by tests).
    .OUTPUTS
        Absolute path of the saved file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StatePath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [hashtable]$State
    )

    if ($null -eq $State) { $State = @{} }

    $file = Get-StateFilePath -StatePath $StatePath
    $tmp  = "$file.tmp"
    $ordered = [ordered]@{}
    foreach ($k in ($State.Keys | Sort-Object)) {
        $ordered[$k] = $State[$k]
    }
    $json = $ordered | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $tmp -Value $json -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $file -Force
    return $file
}

Export-ModuleMember -Function `
    Get-PreviousState, `
    Compare-ReleaseState, `
    Save-CurrentState, `
    Get-ContentHash, `
    Get-RecordKey, `
    Get-StateFilePath
