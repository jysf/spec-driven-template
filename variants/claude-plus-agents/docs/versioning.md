# Versioning

How **this app** versions its own releases. Configured once in
`.repo-context.yaml` (`spec.version.scheme`) and consumed by the release-spec
(DEC-006) and `just next-version`. See [DEC-007](decisions/DEC-007-versioning-default.md).

## Two different "versions" — don't conflate them

| | What it is | Where it lives |
|---|---|---|
| **Template version** | Which spec-driven-template version this repo was scaffolded from — **template provenance** | the top-level `VERSION` file · `just template-version` |
| **App version** | *Your app's* own release version | git tags (and/or your ecosystem file: `package.json`, `Cargo.toml`, `pyproject.toml`) · `just next-version` |

The `VERSION` file **is not your app's version.** It survives `just init` so an
instance can report where it came from. Version your app with **git tags** in
your chosen scheme; keep the app version out of `VERSION`.

## The default: CalVer (`calver`)

```
v2026.07.0     first release this month
v2026.07.1     next patch, same month
v2026.08.0     first release next month
```

Date-based: the year+month come from the calendar, the patch just increments.
There is **no "is this major, minor, or patch?" judgment call** — which is
exactly why it's the default. It fits the majority shape (apps, services, CLIs)
and sorts naturally. `just next-version` computes it for you from existing tags.

## When to switch — pick by delivery shape

The release-spec's **Delivery shapes** line (`binary · package · service ·
library`) is the guide:

- **`semver`** (`vMAJOR.MINOR.PATCH`) — choose this for a **library or public
  API** whose version is a *compatibility promise to consumers* (they pin
  ranges against your API). That promise is what semver exists to encode. semver
  can't be auto-bumped — you decide MAJOR (breaking) / MINOR (feature) / PATCH
  (fix) yourself; `just next-version` prints the current latest and reminds you.
- **`calver`** (default) — apps, services, internal tools, CLIs: no consumer API
  contract, continuous delivery. The date is the honest signal.
- **`monotonic`** (`v1, v2, …`) — when you want the least possible ceremony and
  the number carries no meaning beyond "later is bigger."

Switching is one line:

```yaml
spec:
  version:
    scheme: semver     # calver | semver | monotonic
```

## `just next-version`

Prints the suggested next app version per the configured scheme, derived from
your git tags (degrades to the scheme's first version when there are none yet):

```bash
just next-version          # e.g. "Scheme: calver / Next: v2026.07.0"
just next-version --json   # { "scheme": "calver", "next": "v2026.07.0" }
```

Use it when you cut a release (fill the release-spec's `Version / tag` line),
then tag the release commit with that version.
