# GitHub Profile README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a rich, bilingual GitHub profile README for `eminwhocodes` (Architect Command Center: dark/cyan, team, focus labels, unified private+org stats).

**Architecture:** Public repo named exactly `eminwhocodes/eminwhocodes` with `README.md` (EN, profile-rendered) and `README.tr.md` (TR mirror). Static assets under `assets/`. Stats images load from a self-hosted github-readme-stats deployment whose PAT includes private and org repos; README never stores secrets or private repo names.

**Tech Stack:** GitHub Markdown, SVG/PNG banner, shields.io / skillicons, self-hosted [github-readme-stats](https://github.com/anuraghazra/github-readme-stats) (Vercel), `gh` CLI.

## Global Constraints

- Work only under `c:\www\tek-seferlik-isler\eminwhocodes` (except remote GitHub/Vercel setup).
- English primary file must be named `README.md`; Turkish is `README.tr.md`.
- Theme: dark / tech; accent cyan / electric blue.
- Role copy: Software Architect / Yazılım Mimarı.
- Team: Emin, Mücahit Y., Halil Ç., Musa G. — names + roles only; **no profile links**.
- Stats: single unified block; **no** “private” / “public” labels; **no** private/org repo names.
- Focus areas: generic labels only (see Task 3).
- Contacts: GitHub profile, `https://www.linkedin.com/in/eminwhocodes`, `emin@codron.co`.
- Never commit PATs, `.env` with secrets, or tokens.
- Spec: `docs/superpowers/specs/2026-08-06-github-profile-readme-design.md`.

---

## File map

| Path | Responsibility |
|------|----------------|
| `README.md` | English profile README (GitHub renders this on profile) |
| `README.tr.md` | Turkish mirror; language switcher target |
| `assets/banner.svg` | Dark/cyan hero banner |
| `STATS.md` | Operator notes for self-hosted stats + PAT (no secrets) |
| `docs/superpowers/specs/2026-08-06-github-profile-readme-design.md` | Approved design (already exists) |
| `docs/superpowers/plans/2026-08-06-github-profile-readme.md` | This plan |

Placeholder used until deploy: `STATS_BASE_URL` = `https://github-readme-stats.vercel.app` for first push; after Task 5, replace with the user’s self-hosted URL in both READMEs.

---

### Task 1: Initialize local git repo and remote profile repository

**Files:**
- Create: `c:\www\tek-seferlik-isler\eminwhocodes\.gitignore`
- Create (via `gh`): remote `eminwhocodes/eminwhocodes`

**Interfaces:**
- Consumes: none
- Produces: git repo at local path; remote `origin` pointing at `https://github.com/eminwhocodes/eminwhocodes.git`; `.gitignore` ignoring `.env`, `.env.*`, `*.pem`

- [ ] **Step 1: Create `.gitignore`**

Write `c:\www\tek-seferlik-isler\eminwhocodes\.gitignore`:

```gitignore
.env
.env.*
!.env.example
*.pem
.DS_Store
Thumbs.db
node_modules/
.vercel/
```

- [ ] **Step 2: Init git if needed**

Run (PowerShell):

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
if (-not (Test-Path .git)) { git init }
git status
```

Expected: repository initialized; `.gitignore` and existing `docs/` visible.

- [ ] **Step 3: Create public GitHub profile repo if missing**

Run:

```powershell
gh repo view eminwhocodes/eminwhocodes 2>&1
if ($LASTEXITCODE -ne 0) {
  gh repo create eminwhocodes/eminwhocodes --public --description "Profile README" --source . --remote origin
} else {
  git remote remove origin 2>$null
  git remote add origin https://github.com/eminwhocodes/eminwhocodes.git
}
gh repo view eminwhocodes/eminwhocodes --json name,isPrivate,url
```

Expected: `name` = `eminwhocodes`, `isPrivate` = `false`.

- [ ] **Step 4: Commit scaffolding**

```powershell
git add .gitignore docs/
git commit -m "chore: init profile repo scaffolding and design docs"
```

Expected: commit succeeds (or nothing new if already committed — then skip empty commit).

---

### Task 2: Create dark/cyan banner asset

**Files:**
- Create: `assets/banner.svg`

**Interfaces:**
- Consumes: none
- Produces: `assets/banner.svg` usable as `![banner](assets/banner.svg)` in README; dark fill `#0b1220`, cyan accent `#22d3ee`, text “Emin” + “Software Architect”

- [ ] **Step 1: Ensure assets directory**

```powershell
New-Item -ItemType Directory -Path c:\www\tek-seferlik-isler\eminwhocodes\assets -Force
```

- [ ] **Step 2: Write banner SVG**

Create `c:\www\tek-seferlik-isler\eminwhocodes\assets\banner.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="360" viewBox="0 0 1200 360" role="img" aria-label="Emin — Software Architect">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0b1220"/>
      <stop offset="55%" stop-color="#111827"/>
      <stop offset="100%" stop-color="#0f172a"/>
    </linearGradient>
    <linearGradient id="cyan" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#22d3ee"/>
      <stop offset="100%" stop-color="#38bdf8"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="360" fill="url(#bg)"/>
  <circle cx="980" cy="80" r="140" fill="#22d3ee" opacity="0.08"/>
  <circle cx="1080" cy="260" r="100" fill="#38bdf8" opacity="0.06"/>
  <rect x="64" y="72" width="8" height="216" rx="4" fill="url(#cyan)"/>
  <text x="96" y="150" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="64" font-weight="700" fill="#f8fafc">Emin</text>
  <text x="96" y="210" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="28" font-weight="500" fill="#22d3ee">Software Architect</text>
  <text x="96" y="258" font-family="Consolas, Menlo, monospace" font-size="16" fill="#94a3b8">systems · apis · daemons · web · tooling</text>
</svg>
```

- [ ] **Step 3: Verify file exists and is non-empty**

```powershell
Get-Item c:\www\tek-seferlik-isler\eminwhocodes\assets\banner.svg | Select-Object Length, FullName
```

Expected: `Length` > 500.

- [ ] **Step 4: Commit**

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
git add assets/banner.svg
git commit -m "feat: add dark cyan profile banner"
```

---

### Task 3: Write English `README.md`

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: `assets/banner.svg`; stats image base `STATS_BASE_URL` (use `https://github-readme-stats.vercel.app` until Task 5 replaces it)
- Produces: complete EN profile README matching spec section order

- [ ] **Step 1: Write `README.md` with full content**

Create `c:\www\tek-seferlik-isler\eminwhocodes\README.md` exactly as follows (stats host placeholder is the public demo until self-host URL is swapped in Task 5):

```markdown
<div align="center">

[English](./README.md) · [Türkçe](./README.tr.md)

![banner](./assets/banner.svg)

### Software Architect

Designing and shipping systems end-to-end — from architecture and APIs to daemons, web apps, and the tooling around them. I lead delivery with a small team and care about clear boundaries, reliable ops, and maintainable code.

[GitHub](https://github.com/eminwhocodes) · [LinkedIn](https://www.linkedin.com/in/eminwhocodes) · [emin@codron.co](mailto:emin@codron.co)

</div>

## Tech Stack

<p align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=php,laravel,nodejs,react,nextjs,cs,dotnet,python,docker,bash&theme=dark" alt="Tech stack" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Daemons%20%2F%20Workers-22d3ee?style=for-the-badge&logoColor=0b1220&labelColor=0b1220" alt="Daemons / Workers" />
</p>

## Team

| Name | Role |
|------|------|
| Emin | Software Architect |
| Mücahit Y. | Full Stack |
| Halil Ç. | Project Manager & Support |
| Musa G. | Frontend |

## Focus Areas

- Client platforms & portals
- Internal APIs & integrations
- Background daemons / workers
- E-commerce & ops automation
- Developer tooling & Windows utilities

## Activity

<!-- Unified stats: personal public + private + org (when self-hosted PAT is configured). Do not split private/public labels. -->

<div align="center">
  <img height="170" src="https://github-readme-stats.vercel.app/api?username=eminwhocodes&show_icons=true&theme=radical&hide_border=true&bg_color=0b1220&title_color=22d3ee&icon_color=22d3ee&text_color=e2e8f0&ring_color=22d3ee" alt="GitHub stats" />
  <img height="170" src="https://github-readme-stats.vercel.app/api/top-langs/?username=eminwhocodes&layout=compact&theme=radical&hide_border=true&bg_color=0b1220&title_color=22d3ee&text_color=e2e8f0" alt="Top languages" />
</div>

<div align="center">
  <img src="https://github-readme-activity-graph.vercel.app/graph?username=eminwhocodes&bg_color=0b1220&color=22d3ee&line=38bdf8&point=e2e8f0&area=true&hide_border=true" alt="Activity graph" />
</div>

## Public Highlights

- **[pc-yer-acma](https://github.com/eminwhocodes/pc-yer-acma)** — Windows disk usage analyzer with Docker/Drive cleanup UI
- **[gnu-todo](https://github.com/eminwhocodes/gnu-todo)** — Shell tooling
- **[dev-toys-onayliyorum](https://github.com/eminwhocodes/dev-toys-onayliyorum)** — C# utility
```

- [ ] **Step 2: Structural self-check**

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
Select-String -Path README.md -Pattern 'README.tr.md','Software Architect','Mücahit Y.','Halil Ç.','Musa G.','emin@codron.co','linkedin.com/in/eminwhocodes','Focus Areas','pc-yer-acma','private','Public / Private' 
```

Expected: language switch, role, team names, contacts, focus, public repos match.  
Expected: no matches for literal split labels like `Public / Private`. Mentions of “private” only inside HTML comments about stats config are acceptable; if a visible heading says Private, fix it.

- [ ] **Step 3: Confirm team rows have no markdown links**

```powershell
Select-String -Path README.md -Pattern '\|.*\[.*\]\(http'
```

Expected: no output (team/contact may use links in Contact line only — if this catches Contact links outside tables, instead verify the Team table lines contain no `](` ).

Manual check: Team table cells are plain text only.

- [ ] **Step 4: Commit**

```powershell
git add README.md
git commit -m "feat: add English profile README"
```

---

### Task 4: Write Turkish `README.tr.md`

**Files:**
- Create: `README.tr.md`

**Interfaces:**
- Consumes: same `assets/banner.svg` and same stats URLs as `README.md`
- Produces: TR mirror with identical section order and no team links

- [ ] **Step 1: Write `README.tr.md`**

Create `c:\www\tek-seferlik-isler\eminwhocodes\README.tr.md`:

```markdown
<div align="center">

[English](./README.md) · [Türkçe](./README.tr.md)

![banner](./assets/banner.svg)

### Yazılım Mimarı

Uçtan uca sistemler tasarlıyor ve hayata geçiriyorum — mimari ve API’lerden daemon’lara, web uygulamalarına ve çevre araçlara. Küçük bir ekiple teslimatı yönetiyor; net sınırlar, güvenilir operasyon ve sürdürülebilir kod peşindeyim.

[GitHub](https://github.com/eminwhocodes) · [LinkedIn](https://www.linkedin.com/in/eminwhocodes) · [emin@codron.co](mailto:emin@codron.co)

</div>

## Teknoloji Yığını

<p align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=php,laravel,nodejs,react,nextjs,cs,dotnet,python,docker,bash&theme=dark" alt="Teknoloji yığını" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Daemon%20%2F%20Worker-22d3ee?style=for-the-badge&logoColor=0b1220&labelColor=0b1220" alt="Daemon / Worker" />
</p>

## Ekip

| İsim | Rol |
|------|-----|
| Emin | Yazılım Mimarı |
| Mücahit Y. | Full Stack |
| Halil Ç. | Proje Yöneticisi & Destek |
| Musa G. | Frontend |

## Odak Alanları

- Müşteri platformları ve portaller
- Dahili API’ler ve entegrasyonlar
- Arka plan daemon / worker’ları
- E-ticaret ve operasyon otomasyonu
- Geliştirici araçları ve Windows yardımcıları

## Aktivite

<!-- Birleşik istatistik: kişisel public + private + org (self-hosted PAT sonrası). Private/public ayrımı yok. -->

<div align="center">
  <img height="170" src="https://github-readme-stats.vercel.app/api?username=eminwhocodes&show_icons=true&theme=radical&hide_border=true&bg_color=0b1220&title_color=22d3ee&icon_color=22d3ee&text_color=e2e8f0&ring_color=22d3ee" alt="GitHub istatistikleri" />
  <img height="170" src="https://github-readme-stats.vercel.app/api/top-langs/?username=eminwhocodes&layout=compact&theme=radical&hide_border=true&bg_color=0b1220&title_color=22d3ee&text_color=e2e8f0" alt="En çok kullanılan diller" />
</div>

<div align="center">
  <img src="https://github-readme-activity-graph.vercel.app/graph?username=eminwhocodes&bg_color=0b1220&color=22d3ee&line=38bdf8&point=e2e8f0&area=true&hide_border=true" alt="Aktivite grafiği" />
</div>

## Öne Çıkan Public Projeler

- **[pc-yer-acma](https://github.com/eminwhocodes/pc-yer-acma)** — Docker/Drive temizleme arayüzlü Windows disk kullanım analizi
- **[gnu-todo](https://github.com/eminwhocodes/gnu-todo)** — Shell araçları
- **[dev-toys-onayliyorum](https://github.com/eminwhocodes/dev-toys-onayliyorum)** — C# yardımcı araç
```

- [ ] **Step 2: Verify switcher and TR role string**

```powershell
Select-String -Path README.tr.md -Pattern 'Yazılım Mimarı','Odak Alanları','Ekip','README.md'
```

Expected: all match.

- [ ] **Step 3: Commit**

```powershell
git add README.tr.md
git commit -m "feat: add Turkish profile README"
```

---

### Task 5: Self-hosted stats setup notes + URL wire-up

**Files:**
- Create: `STATS.md`
- Modify: `README.md` (replace stats host when URL known)
- Modify: `README.tr.md` (same)

**Interfaces:**
- Consumes: user-created GitHub PAT with `repo` scope + org access (SSO authorize if needed); Vercel (or similar) deploy of github-readme-stats
- Produces: `STATS.md` operator guide; READMEs pointing at `https://<user-stats-host>` instead of public vercel demo when deploy URL is available

- [ ] **Step 1: Write `STATS.md` (no secrets)**

Create `c:\www\tek-seferlik-isler\eminwhocodes\STATS.md`:

```markdown
# Self-hosted GitHub Readme Stats

Private personal + private org activity is included only when README cards point at **your** deployment with a PAT that can read those repos.

## 1. Create PAT

1. GitHub → Settings → Developer settings → Personal access tokens.
2. Classic token scopes: at least `repo` (private repo read). Fine-grained: repository access to needed private repos + org repos.
3. For orgs with SAML SSO: click **Authorize** next to each org on the token.

Never commit the token. Never put it in README URLs.

## 2. Deploy github-readme-stats

1. Fork or import https://github.com/anuraghazra/github-readme-stats
2. Deploy to Vercel (or similar).
3. Set environment variable `PAT_1` (or as documented upstream) to the token.
4. Note the production base URL, e.g. `https://YOUR_PROJECT.vercel.app`

## 3. Point the profile READMEs

Replace every occurrence of:

`https://github-readme-stats.vercel.app`

with:

`https://YOUR_PROJECT.vercel.app`

in `README.md` and `README.tr.md`.

Keep query params (`username=eminwhocodes`, colors) unchanged.

Activity graph (`github-readme-activity-graph.vercel.app`) is separate; leave public or self-host later. Unified commit counts for private/org primarily come from **github-readme-stats** with PAT.

## 4. Profile contribution graph

GitHub → Profile → Settings → Contributions & activity → enable **Include private contributions on my profile**.

## 5. Verify

Open:

`https://YOUR_PROJECT.vercel.app/api?username=eminwhocodes&show_icons=true`

Confirm totals look higher than public-only (if you have private/org commits). Confirm README on https://github.com/eminwhocodes renders images.
```

- [ ] **Step 2: If user already has a stats base URL, replace hosts now**

If the user provides `https://EXAMPLE.vercel.app`, run:

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
$old = 'https://github-readme-stats.vercel.app'
$new = 'https://EXAMPLE.vercel.app'  # replace with real URL
(Get-Content README.md -Raw) -replace [regex]::Escape($old), $new | Set-Content README.md -NoNewline
(Get-Content README.tr.md -Raw) -replace [regex]::Escape($old), $new | Set-Content README.tr.md -NoNewline
```

If no URL yet: leave public demo URLs; document that private/org counts appear only after Step 1–3 in `STATS.md`.

- [ ] **Step 3: Commit**

```powershell
git add STATS.md README.md README.tr.md
git commit -m "docs: add self-hosted stats setup guide"
```

(If READMEs unchanged, still commit `STATS.md`.)

---

### Task 6: Push and verify on GitHub profile

**Files:**
- None new (remote update)

**Interfaces:**
- Consumes: Tasks 1–5 local commits
- Produces: live profile at `https://github.com/eminwhocodes`

- [ ] **Step 1: Push main branch**

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
git branch -M main
git push -u origin main
```

Expected: push succeeds; repo files visible at `https://github.com/eminwhocodes/eminwhocodes`.

- [ ] **Step 2: Verify profile README surfaces**

Open `https://github.com/eminwhocodes` — the pinned README block should show banner, bio, team, stats images, public highlights.

Open `https://github.com/eminwhocodes/eminwhocodes/blob/main/README.tr.md` and click English/Türkçe switcher links.

- [ ] **Step 3: Checklist against success criteria**

- [ ] EN README on profile
- [ ] TR switch works
- [ ] Architect positioning present
- [ ] Team table without member links
- [ ] No private/org repo names
- [ ] No private/public stats split labels
- [ ] LinkedIn + mailto work
- [ ] No secrets in git (`git grep -i "ghp_" ` should return nothing)

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
git grep -i "ghp_" || echo "no tokens found"
```

Expected: `no tokens found` or empty.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Repo `eminwhocodes/eminwhocodes` public | Task 1 |
| `README.md` + `README.tr.md` + switcher | Tasks 3–4 |
| `assets/` banner dark/cyan | Task 2 |
| Bio, contacts, tech, team, focus, stats, public highlights order | Tasks 3–4 |
| Team no links | Tasks 3–4 checks |
| Unified stats; no private names; PAT self-host | Task 5 |
| Public highlights three repos | Tasks 3–4 |
| Push + verify profile | Task 6 |
| No secrets committed | Tasks 1, 5, 6 |

## Placeholder scan

No TBD/TODO left in task steps. Stats URL may remain on public vercel until user deploys; `STATS.md` defines the exact replace string.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-06-github-profile-readme.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — same session with executing-plans, batched with checkpoints  

Which approach?
