# GitHub Profile README — Design Spec

**Date:** 2026-08-06  
**Repo:** `eminwhocodes/eminwhocodes` (public profile repository)  
**Local path:** `c:\www\tek-seferlik-isler\eminwhocodes`  
**Approach:** Architect Command Center (rich, dark/cyan)

## Goal

A rich GitHub profile README that positions **Emin** as a **Software Architect**, showcases a dark tech visual with cyan accents, includes the team without profile links, and surfaces **combined** activity stats (personal public + private + private org) without labeling or naming private work.

## Decisions (locked)

| Topic | Choice |
|--------|--------|
| Style | Rich (banner, badges, stats, tech icons) |
| Language | English primary (`README.md`) + Turkish (`README.tr.md`) with switcher |
| Role | Software Architect |
| Theme | Dark / tech, cyan / electric blue accent |
| Team | Shown (name + role only; no links) |
| Private visibility | Combined stats only; no private/public split labels |
| Project names | Generic focus labels only for non-public work |
| Contacts | GitHub, LinkedIn (`linkedin.com/in/eminwhocodes`), email (`emin@codron.co`) |

## Files

| Path | Purpose |
|------|---------|
| `README.md` | Profile README (English) — rendered on GitHub profile |
| `README.tr.md` | Turkish mirror with same structure |
| `assets/` | Banner and any static images |
| (optional later) | Self-hosted stats app env / deploy notes — not secrets in repo |

## Section order (both languages)

1. **Language switcher** — `English` | `Türkçe` (relative links between the two README files)
2. **Hero** — dark + cyan banner; name + “Software Architect”
3. **Bio** — 1–2 sentences (copy below)
4. **Contact** — GitHub · LinkedIn · email
5. **Tech stack** — icons / badges
6. **Team** — table, no links
7. **Focus areas** — generic labels
8. **Activity / stats** — unified cards (private + public + org)
9. **Public highlights** — known public repos only

## Copy

### English

- **Title:** Emin · Software Architect
- **Bio:** Designing and shipping systems end-to-end — from architecture and APIs to daemons, web apps, and the tooling around them. I lead delivery with a small team and care about clear boundaries, reliable ops, and maintainable code.

### Turkish

- **Title:** Emin · Yazılım Mimarı
- **Bio:** Uçtan uca sistemler tasarlıyor ve hayata geçiriyorum — mimari ve API’lerden daemon’lara, web uygulamalarına ve çevre araçlara. Küçük bir ekiple teslimatı yönetiyor; net sınırlar, güvenilir operasyon ve sürdürülebilir kod peşindeyim.

## Team

| Name | Role (EN) | Role (TR) |
|------|-----------|-----------|
| Emin | Software Architect | Yazılım Mimarı |
| Mücahit Y. | Full Stack | Full Stack |
| Halil Ç. | Project Manager & Support | Proje Yöneticisi & Destek |
| Musa G. | Frontend | Frontend |

No GitHub/LinkedIn/profile links for any team member in this version.

## Focus areas (generic — no real private/org repo names)

- Client platforms & portals / Müşteri platformları ve portaller
- Internal APIs & integrations / Dahili API’ler ve entegrasyonlar
- Background daemons / workers / Arka plan daemon / worker’ları
- E-commerce & ops automation / E-ticaret ve operasyon otomasyonu
- Developer tooling & Windows utilities / Geliştirici araçları ve Windows yardımcıları

## Tech stack (display)

PHP · Laravel · Node · React · Next.js · C# / .NET · Python · Docker · Daemons / Workers

(Also implied from earlier scope: JS/TS, DevOps/Windows tooling — use icons where available; keep the row scannable, not a wall of badges.)

## Stats & privacy

### Visible

- Aggregate GitHub stats card (commits, streak, etc.) including private personal and private org activity when token allows
- Top languages
- Optional activity graph
- Presentation: **one unified block** — do not label “private” vs “public”

### Not visible

- Private or org repository names
- Any “Private / Public” segregation in the UI copy
- Real client project names (use focus labels instead)

### Implementation notes

1. Deploy a self-hosted instance of [github-readme-stats](https://github.com/anuraghazra/github-readme-stats) (e.g. Vercel).
2. Configure a PAT with `repo` (and org access; complete org SSO authorize if required).
3. Point README image URLs at the self-hosted base URL.
4. Store the token only in the host’s environment — never in README or git.
5. Enable GitHub profile setting “Include private contributions on my profile” for the contribution graph on the profile page itself (separate from README cards).

### Public highlights (safe to name)

Current public repos to feature with short blurbs:

- `pc-yer-acma` — Windows disk usage analyzer with Docker/Drive cleanup UI
- `gnu-todo` — Shell tooling
- `dev-toys-onayliyorum` — C# utility

Pinned repos can also be set in GitHub UI independently of README content.

## Visual

- Dark background feel via banner and card themes (`theme` params favoring dark + cyan accents where supported)
- Accent: cyan / electric blue
- Avoid clutter: prefer one banner, one tech row, one stats row, one team table
- Motion: optional typing SVG or subtle banner only if it stays readable; no excessive trophy walls

## Out of scope (this version)

- Team member profile links
- Listing or linking private/org repos by real name
- Separate private vs public stats sections
- Visitor counters / trophy spam as primary content

## Implementation outline (after spec approval)

1. Create public repo `eminwhocodes/eminwhocodes` if missing; init from local folder.
2. Add `assets/` banner (dark/cyan).
3. Write `README.md` and `README.tr.md` per section order and copy above.
4. Deploy self-hosted stats; wire URLs; document PAT setup for the user (secrets outside repo).
5. Push and verify profile rendering at https://github.com/eminwhocodes.

## Success criteria

- Profile shows rich EN README with working TR switch.
- Architect positioning and team table present without team links.
- Stats reflect combined activity without exposing private/org names or private/public labels.
- Contact links work (LinkedIn + mailto).
- No secrets committed.
