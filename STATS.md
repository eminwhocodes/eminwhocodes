# Private + public + org stats on the profile README

Public mirrors (vercel demos) **cannot** see your private or org repos. This profile uses **local SVG cards** generated with a token that can.

## How it works

1. `scripts/generate-stats.ps1` calls GitHub GraphQL as you (or a PAT).
2. It writes aggregate cards to `assets/stats.svg` and `assets/top-langs.svg`.
3. Language totals include **private/org** code size — **repo names are never written**.
4. README embeds those local files (no third-party stats host required).

## One-time setup (auto refresh)

1. GitHub → Settings → Developer settings → **Personal access tokens (classic)**.
2. Generate token with at least **`repo`** scope.
3. Org access (önemli):
   - **SAML SSO’lu org:** https://github.com/settings/tokens → token satırında **Configure SSO** / **Enable SSO** → ilgili org’larda **Authorize**.
   - **SSO yoksa** bu buton **görünmez** (normal). O zaman classic `repo` token, üye olduğun private org repolarına erişmeli.
   - Hâlâ org gelmiyorsa org sahibi: **Org → Settings → Personal access tokens** (veya Third-party access) → classic PAT’lere izin verildiğinden emin olsun.
4. Open https://github.com/eminwhocodes/eminwhocodes/settings/secrets/actions  
5. New secret name: **`PROFILE_STATS_PAT`** → paste the token (eski secret varsa Update).
6. Actions → **Refresh profile stats** → **Run workflow**.
7. Workflow log’da `org_owners=...` satırına bak: org isimleri yazıyorsa token org’u görüyor demektir.

The workflow also runs daily at 06:00 UTC.

## Manual refresh (local)

```powershell
cd c:\www\tek-seferlik-isler\eminwhocodes
pwsh -File .\scripts\generate-stats.ps1 -Push
```

Uses your logged-in `gh` session (`gh auth login` / existing keyring token with `repo`).

## Contribution graph on the profile page

README cards ≠ the green contribution calendar.

To show private squares on https://github.com/eminwhocodes :

**Profile → Settings → Contributions & activity → Include private contributions on my profile**

## Optional: official github-readme-stats look

If you prefer the classic anuraghazra cards instead of local SVGs:

1. Fork https://github.com/anuraghazra/github-readme-stats  
2. Deploy to Vercel; set env `PAT_1` to the same classic PAT.  
3. Point README `<img src>` hosts to your Vercel URL.

Local SVGs already cover the private/public aggregate need without Vercel.
