# Generates dark/cyan stats SVGs using the authenticated `gh` CLI.
# Includes private + org repos the token can access (aggregate only — no repo names).
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

$contrib = gh api graphql -f query='
query {
  viewer {
    login
    followers { totalCount }
    contributionsCollection {
      totalCommitContributions
      restrictedContributionsCount
      totalPullRequestContributions
      totalIssueContributions
      totalRepositoriesWithContributedCommits
      contributionCalendar { totalContributions }
    }
  }
}' | ConvertFrom-Json

$repoData = gh api graphql -f query='
query {
  viewer {
    repositories(first: 100, ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER], isFork: false) {
      totalCount
      nodes {
        stargazerCount
        languages(first: 10, orderBy: { field: SIZE, direction: DESC }) {
          edges { size node { name color } }
        }
      }
    }
  }
}' | ConvertFrom-Json

$v = $contrib.data.viewer
$c = $v.contributionsCollection
$commits = [int]$c.totalCommitContributions + [int]$c.restrictedContributionsCount
$prs = [int]$c.totalPullRequestContributions
$issues = [int]$c.totalIssueContributions
$contributed = [int]$c.totalRepositoriesWithContributedCommits
$followers = [int]$v.followers.totalCount
$totalContrib = [int]$c.contributionCalendar.totalContributions

$stars = 0
$langMap = @{}
foreach ($node in $repoData.data.viewer.repositories.nodes) {
  $stars += [int]$node.stargazerCount
  foreach ($edge in $node.languages.edges) {
    $name = $edge.node.name
    if (-not $name) { continue }
    if (-not $langMap.ContainsKey($name)) {
      $langMap[$name] = @{ size = 0; color = $edge.node.color }
    }
    $langMap[$name].size += [int64]$edge.size
    if ($edge.node.color) { $langMap[$name].color = $edge.node.color }
  }
}

$langs = $langMap.GetEnumerator() |
  Sort-Object { -$_.Value.size } |
  Select-Object -First 6

$totalLangSize = ($langs | ForEach-Object { $_.Value.size } | Measure-Object -Sum).Sum
if ($totalLangSize -le 0) { $totalLangSize = 1 }

$year = (Get-Date).Year

# --- stats card ---
$statsSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="195" viewBox="0 0 420 195" role="img" aria-label="GitHub stats">
  <rect width="420" height="195" rx="8" fill="#0b1220"/>
  <rect x="0" y="0" width="420" height="3" fill="#22d3ee"/>
  <text x="24" y="38" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="16" font-weight="700" fill="#22d3ee">eminwhocodes's GitHub Stats</text>
  <g font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="14" fill="#e2e8f0">
    <text x="24" y="72">Total Stars</text><text x="280" y="72" fill="#22d3ee" font-weight="600">$stars</text>
    <text x="24" y="98">Commits ($year)</text><text x="280" y="98" fill="#22d3ee" font-weight="600">$commits</text>
    <text x="24" y="124">Pull Requests</text><text x="280" y="124" fill="#22d3ee" font-weight="600">$prs</text>
    <text x="24" y="150">Issues</text><text x="280" y="150" fill="#22d3ee" font-weight="600">$issues</text>
    <text x="24" y="176">Contributed to</text><text x="280" y="176" fill="#22d3ee" font-weight="600">$contributed</text>
  </g>
</svg>
"@

# --- top langs card ---
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

$langsSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="195" viewBox="0 0 420 195" role="img" aria-label="Top languages">
  <rect width="420" height="195" rx="8" fill="#0b1220"/>
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
Write-Host "commits=$commits stars=$stars contributed=$contributed totalContributions=$totalContrib followers=$followers"

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
