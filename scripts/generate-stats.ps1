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
Write-Host "commits_all=$totalCommits private_commits=$privateCommits public_commits=$publicCommits year_contrib_commits=$yearCommits"

$langs = @($langMap.GetEnumerator() | Sort-Object { -$_.Value.size } | Select-Object -First 6)
$totalLangSize = ($langs | ForEach-Object { $_.Value.size } | Measure-Object -Sum).Sum
if ($totalLangSize -le 0) { $totalLangSize = 1 }

$statsSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="210" viewBox="0 0 420 210" role="img" aria-label="GitHub stats">
  <rect width="420" height="210" rx="8" fill="#0b1220"/>
  <rect x="0" y="0" width="420" height="3" fill="#22d3ee"/>
  <text x="24" y="36" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="16" font-weight="700" fill="#22d3ee">${login}'s GitHub Stats</text>
  <g font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" fill="#e2e8f0">
    <text x="24" y="68">Total Stars</text><text x="300" y="68" fill="#22d3ee" font-weight="600">$stars</text>
    <text x="24" y="94">Total Commits</text><text x="300" y="94" fill="#22d3ee" font-weight="600">$totalCommits</text>
    <text x="24" y="120">Repositories</text><text x="300" y="120" fill="#22d3ee" font-weight="600">$repoTotal</text>
    <text x="24" y="146">Pull Requests</text><text x="300" y="146" fill="#22d3ee" font-weight="600">$prs</text>
    <text x="24" y="172">Issues</text><text x="300" y="172" fill="#22d3ee" font-weight="600">$issues</text>
    <text x="24" y="198">Contributed to</text><text x="300" y="198" fill="#22d3ee" font-weight="600">$contributed</text>
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

$statsPath = Join-Path $assets "stats.svg"
$langsPath = Join-Path $assets "top-langs.svg"
[System.IO.File]::WriteAllText($statsPath, $statsSvg.Trim() + "`n")
[System.IO.File]::WriteAllText($langsPath, $langsSvg.Trim() + "`n")

Write-Host "Wrote $statsPath"
Write-Host "Wrote $langsPath"
Write-Host "commits=$totalCommits stars=$stars repos=$repoTotal contributed=$contributed followers=$followers"

if ($Push) {
  Push-Location $root
  try {
    git add assets/stats.svg assets/top-langs.svg
    $pending = git status --porcelain -- assets/stats.svg assets/top-langs.svg
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
