# Generates dark/cyan stats SVGs using the authenticated `gh` CLI.
# Pulls personal OWNER repos + every org the token can list (paginated).
# Aggregate only — no repo names in the SVGs.
#
# Usage:
#   pwsh ./scripts/generate-stats.ps1
#   pwsh ./scripts/generate-stats.ps1 -Push

param(
  [switch]$Push
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$assets = Join-Path $root "assets"
New-Item -ItemType Directory -Path $assets -Force | Out-Null

function Escape-Xml([string]$s) {
  if ($null -eq $s) { return "" }
  return ($s -replace "&", "&amp;" -replace "<", "&lt;" -replace ">", "&gt;" -replace '"', "&quot;")
}

function Invoke-GhGraphql {
  param([string]$Query, [hashtable]$Vars = @{})
  $args = @("api", "graphql", "-f", "query=$Query")
  foreach ($k in $Vars.Keys) {
    $args += @("-f", "$k=$($Vars[$k])")
  }
  $raw = & gh @args 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "gh graphql failed: $raw"
  }
  $json = $raw | ConvertFrom-Json
  if ($json.errors) {
    $msg = ($json.errors | ForEach-Object { $_.message }) -join "; "
    throw "GraphQL errors: $msg"
  }
  return $json
}

$viewerMeta = Invoke-GhGraphql -Query 'query { viewer { id login followers { totalCount } contributionsCollection { totalCommitContributions restrictedContributionsCount totalPullRequestContributions totalIssueContributions totalRepositoriesWithContributedCommits contributionCalendar { totalContributions } } organizations(first: 50) { nodes { login } } } }'
$authorId = $viewerMeta.data.viewer.id
$login = $viewerMeta.data.viewer.login
$c = $viewerMeta.data.viewer.contributionsCollection
$followers = [int]$viewerMeta.data.viewer.followers.totalCount
$prs = [int]$c.totalPullRequestContributions
$issues = [int]$c.totalIssueContributions
$contributed = [int]$c.totalRepositoriesWithContributedCommits
$yearCommits = [int]$c.totalCommitContributions + [int]$c.restrictedContributionsCount

$repoByKey = @{}

function Add-RepoNodes {
  param($Nodes, [string]$Source)
  foreach ($node in $Nodes) {
    if (-not $node -or -not $node.nameWithOwner) { continue }
    $key = $node.nameWithOwner
    if ($repoByKey.ContainsKey($key)) { continue }
    $repoByKey[$key] = @{
      Source = $Source
      IsPrivate = [bool]$node.isPrivate
      Owner = $node.owner.login
      Stars = [int]$node.stargazerCount
      Commits = 0
      Languages = @()
    }
    if ($node.defaultBranchRef -and $node.defaultBranchRef.target -and $node.defaultBranchRef.target.history) {
      $repoByKey[$key].Commits = [int]$node.defaultBranchRef.target.history.totalCount
    }
    if ($node.languages -and $node.languages.edges) {
      $repoByKey[$key].Languages = @($node.languages.edges)
    }
  }
}

$repoFields = @"
nodes {
  nameWithOwner
  isPrivate
  owner { login }
  stargazerCount
  languages(first: 10, orderBy: { field: SIZE, direction: DESC }) {
    edges { size node { name color } }
  }
  defaultBranchRef {
    target {
      ... on Commit {
        history(author: { id: `$authorId }) { totalCount }
      }
    }
  }
}
pageInfo { hasNextPage endCursor }
"@

# Personal repos (OWNER), paginated
$cursor = $null
do {
  if ($cursor) {
    $q = "query (`$authorId: ID!, `$after: String!) { viewer { repositories(first: 50, after: `$after, ownerAffiliations: [OWNER], isFork: false) { totalCount $repoFields } } }"
    $page = Invoke-GhGraphql -Query $q -Vars @{ authorId = $authorId; after = $cursor }
  } else {
    $q = "query (`$authorId: ID!) { viewer { repositories(first: 50, ownerAffiliations: [OWNER], isFork: false) { totalCount $repoFields } } }"
    $page = Invoke-GhGraphql -Query $q -Vars @{ authorId = $authorId }
  }
  $conn = $page.data.viewer.repositories
  Add-RepoNodes -Nodes $conn.nodes -Source "personal"
  $personalTotal = [int]$conn.totalCount
  if ($conn.pageInfo.hasNextPage) { $cursor = $conn.pageInfo.endCursor } else { $cursor = $null }
} while ($cursor)

# Each organization — full list (this is what viewer.repositories misses)
$orgTotals = @{}
foreach ($orgNode in $viewerMeta.data.viewer.organizations.nodes) {
  $orgLogin = $orgNode.login
  $cursor = $null
  $fetched = 0
  do {
    if ($cursor) {
      $q = "query (`$authorId: ID!, `$org: String!, `$after: String!) { organization(login: `$org) { repositories(first: 30, after: `$after, isFork: false) { totalCount $repoFields } } }"
      $page = Invoke-GhGraphql -Query $q -Vars @{ authorId = $authorId; org = $orgLogin; after = $cursor }
    } else {
      $q = "query (`$authorId: ID!, `$org: String!) { organization(login: `$org) { repositories(first: 30, isFork: false) { totalCount $repoFields } } }"
      $page = Invoke-GhGraphql -Query $q -Vars @{ authorId = $authorId; org = $orgLogin }
    }
    if (-not $page.data.organization) {
      Write-Host "WARN: cannot read organization $orgLogin"
      break
    }
    $conn = $page.data.organization.repositories
    $orgTotals[$orgLogin] = [int]$conn.totalCount
    Add-RepoNodes -Nodes $conn.nodes -Source "org:$orgLogin"
    $fetched += @($conn.nodes).Count
    if ($conn.pageInfo.hasNextPage) { $cursor = $conn.pageInfo.endCursor } else { $cursor = $null }
  } while ($cursor)
  Write-Host "org=$orgLogin api_total=$($orgTotals[$orgLogin]) fetched_nodes=$fetched"
}

$stars = 0
$totalCommits = 0
$privateCommits = 0
$publicCommits = 0
$privateCount = 0
$personalCommits = 0
$orgCommits = 0
$langMap = @{}
$bySource = @{}

foreach ($key in $repoByKey.Keys) {
  $r = $repoByKey[$key]
  $stars += $r.Stars
  $totalCommits += $r.Commits
  if ($r.IsPrivate) {
    $privateCount++
    $privateCommits += $r.Commits
  } else {
    $publicCommits += $r.Commits
  }
  if ($r.Source -eq "personal") {
    $personalCommits += $r.Commits
  } else {
    $orgCommits += $r.Commits
  }
  $src = $r.Source
  if (-not $bySource.ContainsKey($src)) { $bySource[$src] = 0 }
  $bySource[$src]++

  foreach ($edge in $r.Languages) {
    $name = $edge.node.name
    if (-not $name) { continue }
    if (-not $langMap.ContainsKey($name)) {
      $langMap[$name] = @{ size = 0; color = $edge.node.color }
    }
    $langMap[$name].size += [int64]$edge.size
    if ($edge.node.color) { $langMap[$name].color = $edge.node.color }
  }
}

$repoTotal = $repoByKey.Count
$sourceSummary = ($bySource.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
Write-Host "repos_unique=$repoTotal private=$privateCount sources: $sourceSummary"
Write-Host "commits_all=$totalCommits private_commits=$privateCommits public_commits=$publicCommits personal_commits=$personalCommits org_commits=$orgCommits year_contrib_commits=$yearCommits"

$langs = @($langMap.GetEnumerator() | Sort-Object { -$_.Value.size } | Select-Object -First 6)
$totalLangSize = ($langs | ForEach-Object { $_.Value.size } | Measure-Object -Sum).Sum
if ($totalLangSize -le 0) { $totalLangSize = 1 }

# --- Last-year daily heatmap from authored commits (includes private/org) ---
$sinceDt = (Get-Date).ToUniversalTime().Date.AddYears(-1)
$sinceIso = $sinceDt.ToString("yyyy-MM-ddT00:00:00Z")
$dayCounts = @{}
$yearCommitEvents = 0
$maxPerRepo = 400

Write-Host "Collecting last-year commit dates since $sinceIso ..."
foreach ($key in ($repoByKey.Keys | Sort-Object)) {
  $parts = $key.Split('/')
  if ($parts.Count -ne 2) { continue }
  $owner = $parts[0]
  $name = $parts[1]
  $cursor = $null
  $got = 0
  do {
    try {
      if ($cursor) {
        $q = 'query ($owner: String!, $name: String!, $authorId: ID!, $since: GitTimestamp!, $after: String!) { repository(owner: $owner, name: $name) { defaultBranchRef { target { ... on Commit { history(author: {id: $authorId}, since: $since, after: $after, first: 100) { nodes { committedDate } pageInfo { hasNextPage endCursor } } } } } } }'
        $page = Invoke-GhGraphql -Query $q -Vars @{ owner = $owner; name = $name; authorId = $authorId; since = $sinceIso; after = $cursor }
      } else {
        $q = 'query ($owner: String!, $name: String!, $authorId: ID!, $since: GitTimestamp!) { repository(owner: $owner, name: $name) { defaultBranchRef { target { ... on Commit { history(author: {id: $authorId}, since: $since, first: 100) { nodes { committedDate } pageInfo { hasNextPage endCursor } } } } } } }'
        $page = Invoke-GhGraphql -Query $q -Vars @{ owner = $owner; name = $name; authorId = $authorId; since = $sinceIso }
      }
    } catch {
      Write-Host "WARN: history skip $key :: $($_.Exception.Message)"
      break
    }
    $hist = $null
    if ($page.data.repository -and $page.data.repository.defaultBranchRef -and $page.data.repository.defaultBranchRef.target) {
      $hist = $page.data.repository.defaultBranchRef.target.history
    }
    if (-not $hist) { break }
    foreach ($node in @($hist.nodes)) {
      if (-not $node.committedDate) { continue }
      $day = ([datetime]$node.committedDate).ToUniversalTime().ToString("yyyy-MM-dd")
      if (-not $dayCounts.ContainsKey($day)) { $dayCounts[$day] = 0 }
      $dayCounts[$day]++
      $yearCommitEvents++
      $got++
    }
    if ($got -ge $maxPerRepo) { break }
    if ($hist.pageInfo.hasNextPage) { $cursor = $hist.pageInfo.endCursor } else { $cursor = $null }
  } while ($cursor)
}
Write-Host "year_commit_events=$yearCommitEvents distinct_days=$($dayCounts.Count)"

$today = (Get-Date).ToUniversalTime().Date
$start = $sinceDt
while ($start.DayOfWeek -ne [DayOfWeek]::Sunday) { $start = $start.AddDays(-1) }
$weeksList = New-Object System.Collections.Generic.List[object]
$cursorDay = $start
while ($cursorDay -le $today) {
  $week = @()
  for ($i = 0; $i -lt 7; $i++) {
    $d = $cursorDay.AddDays($i)
    $key = $d.ToString("yyyy-MM-dd")
    $cnt = if ($dayCounts.ContainsKey($key)) { [int]$dayCounts[$key] } else { 0 }
    if ($d -lt $sinceDt -or $d -gt $today) { $cnt = -1 }
    $week += @{ Date = $key; Count = $cnt }
  }
  [void]$weeksList.Add($week)
  $cursorDay = $cursorDay.AddDays(7)
}

$maxDay = 1
foreach ($week in $weeksList) {
  foreach ($d in $week) {
    if ($d.Count -gt $maxDay) { $maxDay = $d.Count }
  }
}

function Get-HeatColor([int]$count, [int]$max) {
  if ($count -lt 0) { return "#0b1220" }
  if ($count -le 0) { return "#1e293b" }
  $t = [math]::Min(1.0, $count / [double]$max)
  if ($t -lt 0.25) { return "#0e4429" }
  if ($t -lt 0.5) { return "#006d32" }
  if ($t -lt 0.75) { return "#26a641" }
  return "#39d353"
}

$cell = 12
$gap = 3
$gridX = 48
$gridY = 72
$heatCells = New-Object System.Collections.Generic.List[string]
$monthLabels = New-Object System.Collections.Generic.List[string]
$lastMonth = -1
for ($wi = 0; $wi -lt $weeksList.Count; $wi++) {
  $week = $weeksList[$wi]
  $month = ([datetime]$week[0].Date).Month
  if ($month -ne $lastMonth) {
    $label = ([datetime]$week[0].Date).ToString("MMM", [cultureinfo]::InvariantCulture)
    $x = $gridX + $wi * ($cell + $gap)
    [void]$monthLabels.Add("<text x=`"$x`" y=`"58`" font-family=`"Segoe UI, Helvetica, Arial, sans-serif`" font-size=`"11`" fill=`"#94a3b8`">$label</text>")
    $lastMonth = $month
  }
  for ($di = 0; $di -lt 7; $di++) {
    $count = [int]$week[$di].Count
    $color = Get-HeatColor $count $maxDay
    $x = $gridX + $wi * ($cell + $gap)
    $y = $gridY + $di * ($cell + $gap)
    [void]$heatCells.Add("<rect x=`"$x`" y=`"$y`" width=`"$cell`" height=`"$cell`" rx=`"2`" fill=`"$color`"/>")
  }
}

$dayLabels = @"
  <text x="28" y="$($gridY + 10)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="10" fill="#94a3b8">Mon</text>
  <text x="28" y="$($gridY + 10 + 2*($cell+$gap))" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="10" fill="#94a3b8">Wed</text>
  <text x="28" y="$($gridY + 10 + 4*($cell+$gap))" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="10" fill="#94a3b8">Fri</text>
"@

$heatWidth = [math]::Max(900, $gridX + ($weeksList.Count * ($cell + $gap)) + 24)
$heatBottom = $gridY + 7 * ($cell + $gap) + 8
$legendY = $heatBottom + 18
$graphW = $heatWidth
$barTrack = [math]::Max(400, $graphW - 280)
$barMax = [math]::Max(1, $totalCommits)
$personalW = [math]::Max(8, [math]::Round($barTrack * $personalCommits / $barMax))
$orgW = [math]::Max(8, [math]::Round($barTrack * $orgCommits / $barMax))
$totalW = $barTrack
$personalPct = if ($totalCommits -gt 0) { [math]::Round(100.0 * $personalCommits / $totalCommits, 1) } else { 0 }
$orgPct = if ($totalCommits -gt 0) { [math]::Round(100.0 * $orgCommits / $totalCommits, 1) } else { 0 }
$barY0 = $legendY + 40
$barY1 = $barY0 + 46
$barY2 = $barY1 + 46
$activityHeight = $barY2 + 50
$yearLabel = "{0:N0}" -f $yearCommitEvents

$statsSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="140" viewBox="0 0 420 140" role="img" aria-label="GitHub stats">
  <rect width="420" height="140" rx="8" fill="#0b1220"/>
  <rect x="0" y="0" width="420" height="3" fill="#22d3ee"/>
  <text x="24" y="36" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="16" font-weight="700" fill="#22d3ee">${login}'s GitHub Stats</text>
  <g font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="15" fill="#e2e8f0">
    <text x="24" y="72">Total Stars</text><text x="300" y="72" fill="#22d3ee" font-weight="600">$stars</text>
    <text x="24" y="100">Total Commits</text><text x="300" y="100" fill="#22d3ee" font-weight="600">$totalCommits</text>
    <text x="24" y="128">Repositories</text><text x="300" y="128" fill="#22d3ee" font-weight="600">$repoTotal</text>
  </g>
</svg>
"@

$y = 72
$langRows = foreach ($entry in $langs) {
  $name = Escape-Xml $entry.Key
  $color = if ($entry.Value.color) { $entry.Value.color } else { "#22d3ee" }
  $pct = [math]::Round(100.0 * $entry.Value.size / $totalLangSize, 1)
  $barW = [math]::Max(4, [math]::Round(220 * $entry.Value.size / $totalLangSize))
  $row = @"
  <text x="24" y="$y" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="13" fill="#e2e8f0">$name</text>
  <text x="370" y="$y" text-anchor="end" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="12" fill="#94a3b8">${pct}%</text>
  <rect x="24" y="$($y + 6)" width="220" height="6" rx="3" fill="#1e293b"/>
  <rect x="24" y="$($y + 6)" width="$barW" height="6" rx="3" fill="$color"/>
"@
  $y += 28
  $row
}
$langsHeight = [math]::Max(195, $y + 16)

$langsSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="$langsHeight" viewBox="0 0 420 $langsHeight" role="img" aria-label="Top languages">
  <rect width="420" height="$langsHeight" rx="8" fill="#0b1220"/>
  <rect x="0" y="0" width="420" height="3" fill="#22d3ee"/>
  <text x="24" y="38" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="16" font-weight="700" fill="#22d3ee">Top Languages</text>
$($langRows -join "`n")
</svg>
"@

$activitySvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$graphW" height="$activityHeight" viewBox="0 0 $graphW $activityHeight" role="img" aria-label="Contribution activity">
  <rect width="$graphW" height="$activityHeight" rx="12" fill="#0b1220"/>
  <rect x="0" y="0" width="$graphW" height="3" fill="#22d3ee"/>
  <text x="28" y="36" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="18" font-weight="700" fill="#e2e8f0">$yearLabel commits in the last year</text>
  <text x="28" y="54" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="11" fill="#94a3b8">Daily authored commits across personal + organization repos (includes private)</text>
$($monthLabels -join "`n")
$dayLabels
$($heatCells -join "`n")
  <text x="28" y="$legendY" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="11" fill="#94a3b8">Less</text>
  <rect x="60" y="$($legendY - 10)" width="12" height="12" rx="2" fill="#1e293b"/>
  <rect x="76" y="$($legendY - 10)" width="12" height="12" rx="2" fill="#0e4429"/>
  <rect x="92" y="$($legendY - 10)" width="12" height="12" rx="2" fill="#006d32"/>
  <rect x="108" y="$($legendY - 10)" width="12" height="12" rx="2" fill="#26a641"/>
  <rect x="124" y="$($legendY - 10)" width="12" height="12" rx="2" fill="#39d353"/>
  <text x="142" y="$legendY" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="11" fill="#94a3b8">More</text>

  <text x="28" y="$($barY0 - 16)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="13" font-weight="700" fill="#22d3ee">All-time authored commits</text>
  <text x="28" y="$($barY0 + 12)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" fill="#e2e8f0">Personal</text>
  <text x="160" y="$($barY0 + 12)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="12" fill="#64748b">${personalPct}%</text>
  <rect x="220" y="$barY0" width="$barTrack" height="14" rx="7" fill="#1e293b"/>
  <rect x="220" y="$barY0" width="$personalW" height="14" rx="7" fill="#22d3ee"/>
  <text x="$($graphW - 28)" y="$($barY0 + 12)" text-anchor="end" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" font-weight="700" fill="#22d3ee">$personalCommits</text>

  <text x="28" y="$($barY1 + 12)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" fill="#e2e8f0">Organization</text>
  <text x="160" y="$($barY1 + 12)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="12" fill="#64748b">${orgPct}%</text>
  <rect x="220" y="$barY1" width="$barTrack" height="14" rx="7" fill="#1e293b"/>
  <rect x="220" y="$barY1" width="$orgW" height="14" rx="7" fill="#38bdf8"/>
  <text x="$($graphW - 28)" y="$($barY1 + 12)" text-anchor="end" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" font-weight="700" fill="#38bdf8">$orgCommits</text>

  <text x="28" y="$($barY2 + 12)" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" fill="#e2e8f0">Total</text>
  <rect x="220" y="$barY2" width="$barTrack" height="14" rx="7" fill="#1e293b"/>
  <rect x="220" y="$barY2" width="$totalW" height="14" rx="7" fill="#67e8f9"/>
  <text x="$($graphW - 28)" y="$($barY2 + 12)" text-anchor="end" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" font-weight="700" fill="#67e8f9">$totalCommits</text>
</svg>
"@

$statsPath = Join-Path $assets "stats.svg"
$langsPath = Join-Path $assets "top-langs.svg"
$activityPath = Join-Path $assets "activity-graph.svg"
[System.IO.File]::WriteAllText($statsPath, $statsSvg.Trim() + "`n")
[System.IO.File]::WriteAllText($langsPath, $langsSvg.Trim() + "`n")
[System.IO.File]::WriteAllText($activityPath, $activitySvg.Trim() + "`n")

Write-Host "Wrote $statsPath"
Write-Host "Wrote $langsPath"
Write-Host "Wrote $activityPath"
Write-Host "commits=$totalCommits stars=$stars repos=$repoTotal year_events=$yearCommitEvents"

if ($Push) {
  Push-Location $root
  try {
    git add assets/stats.svg assets/top-langs.svg assets/activity-graph.svg
    $pending = git status --porcelain -- assets/stats.svg assets/top-langs.svg assets/activity-graph.svg
    if ($pending) {
      git commit -m "chore: refresh profile stats cards (private+public aggregate)"
      git push origin HEAD
    } else {
      Write-Host "No stats changes to commit."
    }
  } finally {
    Pop-Location
  }
}
