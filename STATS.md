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