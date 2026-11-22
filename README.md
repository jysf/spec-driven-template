# Spec-Driven Multi-Agent Repo Template

A GitHub template for building software with AI agents, where the repo holds what the agent can't remember. An agent starts every session cold: the decisions made yesterday are gone, and over a few weeks the codebase drifts into competing patterns nobody chose. Here the **repo is the app** and also its memory. Work arrives in **projects** (waves like "MVP" or "v2"), split into **stages**, split into **specs**, and each spec runs the same five-phase cycle: frame, design, build, verify, ship. Architecture, constraints and decision records (`DEC-*`) live at repo level, so they outlast every project that produced them.

The process keeps planning, building and checking in separate sessions. Design writes the approach and its decisions into the spec, then hands build to a fresh session or agent through a `HANDOFF-NNN`, and verify to another. That forces the context onto the page and keeps the review independent; the agent that ran each cycle reports back its verdict, model and measured cost. Not everything needs the full cycle: a **patch** (patch → verify → ship) handles a bounded fix, and a **spike** (spike → land) is for exploring before you know the shape. You pick the lane by stakes, not size. At ship, each spec records what a user can now do that they couldn't before, and release notes and reports are assembled from those answers instead of written from memory.

Everything is plain markdown with YAML front-matter, driven by bash scripts behind `just`, with no other dependencies. In practice you talk to Claude — "what's ready?", "start the next spec", "land that spike" — and it runs the commands, whose `--json` output is a versioned contract. Read views (`just dash`, `just ready`, `just calibration`) show where things stand, and gates (`validate`, `decisions-audit`, `cost-audit`, `id-audit`) fail CI when the record is incomplete. The agent does the work; four calls stay yours: whether to go or kill, which lane a change belongs in, whether to accept a rejection from verify, and whether a reflection is honest.

The template was shaped by seven real projects, from Go and Rust CLIs to a browser game. Its features were invented in those projects first and adopted only after recurring (the N=3 rule). Across them, two things prevented nearly all errors: the independent verify and the decision log. Every defect that still escaped was about whether the software *ran*, not whether its logic was right, which is why release specs carry a runtime pre-flight. Fixes reach existing projects through `just template-update`.

**For the longer version, read [docs/OVERVIEW.md](docs/OVERVIEW.md)** — why it's shaped this way, the evidence, and the honest limits.

## Hierarchy

```
Repo (the app — persists forever)
 └─ Project (a wave of work: "MVP", "v2 improvements", "redesign")
     └─ Stage (a coherent chunk within a project)
         └─ Spec (an individual task)
              └─ Cycle (Frame → Design → Build → Verify → Ship)
```

- **Repo** accumulates architecture, conventions, constraints, and decisions across all projects.
- **Projects** are bounded waves of work. You may have one active project, several sequential projects over time, or (rarely) multiple active projects.
- **Stages** are epic-sized chunks within a project. A project typically has 2–5 stages.
- **Specs** are individual implementable tasks. Each belongs to exactly one stage.
- **Cycles** are the 5-phase lifecycle a spec goes through.

## Using this template

**Option A — GitHub template (recommended):**

Click **"Use this template"** at the top of this repo on GitHub. Create your new repo. Clone it. Then inside your new repo:

```bash
just init
```

This asks which variant you want (`claude-plus-agents`, the default, or the deprecated `claude-only`), confirms the choice (it can't be re-run), moves the right files to the repo root, and removes what you don't need — including the template's own docs and its example project and DEC, so `PROJ-001` and `DEC-001` are free for yours. GitHub's template feature already gives you a clean history, so answer **N** when `init` offers to reset it.

Already know the variant? `just init claude-plus-agents` skips the prompts (and leaves git history alone).

**Option B — Clone directly:**

```bash
git clone https://github.com/YOUR-USERNAME/THIS-TEMPLATE.git my-new-repo
cd my-new-repo
just init      # answer 'y' when it offers a fresh git history
```

On a clone, `just init` asks whether to **start a fresh git history** — answer **y** to discard the template's commits and begin your project on a clean `main`. It records which template version you came from in the initial commit (provenance). You can also do this later with `just fresh-start`.

## After `just init`

You'll have a repo root containing:
- `AGENTS.md` — conventions for all agents working here
- `CLAUDE.md` — pointer to `AGENTS.md` for Claude Code
- `GETTING_STARTED.md` — walkthrough for your first project
- `FIRST_SESSION_PROMPTS.md` — copy-paste prompts for each phase
- `.repo-context.yaml` — describes the app (the repo)
- `justfile` — commands you'll run daily
- `docs/`, `guidance/`, `decisions/` — repo-level (accumulate across all projects)
  - `guidance/recommended-tools.md` — optional, project-level tool escalations (Mermaid is the default for diagrams; Structurizr, LineSpec, etc. when you outgrow it)
- `SECURITY.md` — the trust model for your repo (adapt the reporting section to your team)
- `projects/_templates/` — the brief, stage and spec templates your first project starts from

**Next step:** open `GETTING_STARTED.md` and follow it.

## The two variants at a glance

### `claude-plus-agents/` — use this one

Claude designs each spec. Build and verify are each handed off through a
`HANDOFF-NNN` document, usually to a fresh Claude session or subagent (another
tool such as Kilo Code, Factory Droids or Cursor also works). The agent that ran
the cycle fills in its verdict, model and measured cost, and `just handback-sync`
copies them into the spec.

The handoff pays off even when every agent is Claude: build starts from a clean
context with only what design wrote down, verify stays independent of the build,
and cost is measured per cycle by the agent that ran it.

### `claude-only/` — deprecated

One session plays every role, with the build context folded into each spec's
`## Implementation Context` section and no handoffs. It still scaffolds (`just
init claude-only` prints a notice) and existing instances keep getting fixes
through `just template-update`, but new projects should not start on it. See
[DEC-015](docs/decisions/DEC-015-one-variant-claude-plus-agents.md).

The two share every script and 31 of their 45 common files; claude-plus-agents
adds the handoff template.

## `just` commands available

Run `just --list` to see everything. Every read command takes `--json` (a
versioned envelope — see [DEC-001](docs/decisions/DEC-001-interface-contract.md)).

**Setup**

| Command | What it does |
|---|---|
| `just init [variant]` | One-time: choose variant (asks and confirms, or pass `claude-plus-agents`; `claude-only` is deprecated), scaffold the repo |
| `just list-variants` | List the variants (useful before `init`) |
| `just fresh-start` | Discard the template's git history and start a clean `main` (what `init` offers on a clone) |
| `just info` | Print the active project and variant |
| `just template-version` | The template version your repo was scaffolded from; `--json` |

**The daily loop**

| Command | What it does |
|---|---|
| `just new-stage "title" PROJ-NNN` | Scaffold a new stage in the active (or named) project |
| `just frame-stage STAGE-NNN` | Promote a stage's "(not yet written)" backlog lines into outline specs at `cycle: frame`, with stable ids so `depends_on` can point at them; `--dry-run` |
| `just new-spec "title" STAGE-NNN` | Scaffold a new spec with next available ID |
| `just new-release-spec "vX" STAGE-NNN` | Scaffold a release spec with a generic runtime pre-flight checklist (or `new-spec … --release`) |
| `just new-handoff SPEC-NNN build\|verify [--to <agent>]` | Scaffold a delegation handoff (claude-plus-agents) — one per delegated cycle; `to_agent` from `tier_map.<cycle>`, or `--to` for this one handoff |
| `just handback-sync SPEC-NNN` | Transcribe the agent's self-reported cost from its handoffs into the spec — the orchestrator never estimates a delegated cycle. Carries the handback's `agent` (the model that actually ran) and `basis` (how the tokens were measured) |
| `just advance-cycle SPEC-NNN verify` | Update a spec's `task.cycle` field; leaving verify stamps `verify_verdict` and appends it to `verify_rounds` |
| `just archive-spec SPEC-NNN` | Move a shipped spec to `done/` + update stage backlog + stamp `shipped_at`; says how many unwritten backlog items the stage still holds |
| `just close-project PROJ-NNN` | Close a project: refuses on in-flight specs (when claiming `shipped`), an empty reflection, or undisposed signals; stamps `shipped_at`; prints the cost/value/decision rollup. `--dry-run`, `--json` |

**The other lanes**

| Command | What it does |
|---|---|
| `just new-patch "title"` | Scaffold a patch — the lightweight fix lane (collapsed patch→verify→ship, keeps independent verify + DEC) |
| `just archive-patch PATCH-NNN` | File a shipped patch under `patches/done/` (no stage bookkeeping — a patch attaches to the project) |
| `just new-spike "question" [TIMEBOX] [MODE] [PROJ-NNN]` | Scaffold a spike — the bounded-exploration lane (collapsed spike→land, no verify). `MODE=build` is a vibe-coding session. Lives at the repo root; may precede any project |
| `just archive-spike SPIKE-NNN` | File a **landed** spike under `spikes/done/` — refuses one with no `spike.outcome` |

**Views**

| Command | What it does |
|---|---|
| `just dash` | The project dashboard — one read view, many lenses: `dash now`/`next`/`future`/`ledger` (= status/backlog/roadmap/specs-by-stage), plus `dash decisions`/`questions`/`signals`/`patches`/`spikes`/`defects`/`context`/`constraints`/`handoffs`; no arg stitches an overview with governance flags |
| `just status` | Current state: active project, stage, specs by cycle, stale items |
| `just backlog` | What's next, spec-grained: in-flight specs, un-promoted backlog bullets, upcoming-stage counts; `--all` |
| `just roadmap` | Where the project is going, stage-grained: status, date range, spec counts |
| `just specs-by-stage` | Flat ledger of every spec by stage (all projects); `--active` or `PROJ-NNN` to scope |
| `just ready` | The ready set: in-flight specs whose `depends_on` have all shipped and nobody holds — what to pick up next, and the safely-parallel batch for sub-agents |
| `just claim SPEC-NNN WHO` / `just unclaim SPEC-NNN` | Take or release a spec's advisory lease so two agents don't grab the same work; `--force` steals a held claim |
| `just calibration` | Expected vs actual size and tokens for shipped specs, with each spec's cost `basis`; flags a token band that mixes bases. `--basis transcript` to compare within one, `--all` |

**Gates and audits**

| Command | What it does |
|---|---|
| `just validate` | Fail if any spec's front-matter is missing required structural fields or has invalid enums, or if any front matter under `projects/` or `decisions/` does not parse as YAML (ruby when installed, else a weaker bash check; the schema gate, see `docs/schema-reference.md`) |
| `just decisions-audit` | Lint `DEC-*` files + warn on scope conflicts; `--changed` flags decisions governing pending edits |
| `just decisions-index` | Regenerate `decisions/INDEX.md` (id · title · confidence · status · project · supersedes); `--check` fails if stale |
| `just id-audit` | Fail if one artifact id (SPEC/STAGE/PATCH/SPIKE/HANDOFF/DEC) is used by two different artifacts across this checkout, other worktrees and local branches; collisions already renumbered are listed but pass |
| `just cost-audit` | Fail if any shipped spec is missing real build/verify cost (`tokens_total`); same check the CI `cost-data` job runs |

**Reports and releases**

| Command | What it does |
|---|---|
| `just report daily \| weekly [DATE] \| status` | Generate a report: curated daily, weekly-aggregate, or an uncurated `status` snapshot (`report-daily` / `report-weekly` remain as permanent aliases) |
| `just review` | Load recent activity and print the Weekly Review prompt |
| `just lifetime-data` / `lifetime-report` / `lifetime-save` | Whole-repo history: the raw data report, the same wrapped in a synthesis prompt for an LLM, or saved to `reports/lifetime/` |
| `just release-notes [STAGE-NNN\|PROJ-NNN\|--all]` | Assemble outward-facing release notes from what shipped specs already recorded; `--prompt` wraps them in a synthesis ask |
| `just next-version` | Suggest this app's next release version per its scheme (default CalVer `vYYYY.MM.PATCH`) |
| `just build-info` | Build provenance stamp — a `git describe` ref + commit + dirty flag, to bake into the artifact so a build traces back to source |

**Your app's own commands** — `install`, `dev`, `build`, `test`, `lint`,
`typecheck` live in `app.just`, which you own; the stubs print a reminder until
you fill them in, and template updates never touch that file.

**Maintainers** (run from this template repo, not an instance)

| Command | What it does |
|---|---|
| `just template-selftest` | The template's own test suite: scaffolds a throwaway repo and runs init → full cycle → reports → audits |
| `just template-update <instance>` | Update an instance's template-managed files to this version — unedited files replaced, edited ones three-way merged, conflicts never written (drafts saved elsewhere; `--take PATH` after review). Dry run by default; `--apply`, `--base X.Y.Z` |

## Documentation

Start here, in this order:

- [docs/OVERVIEW.md](docs/OVERVIEW.md) — what this is and why: *the agent has no memory; the repo is the memory*. The cycle, the lanes, and what seven real projects showed.
- [docs/PLAYBOOK.md](docs/PLAYBOOK.md) — the full arc, **including the part before you have a repo**: shaping the idea, decomposing it, the three on-ramps (greenfield / prototype-first / existing repo), and how to tell whether the process is working for you.
- [docs/USAGE.md](docs/USAGE.md) — the daily loop in depth: project → stage → spec → cycle, the read-only views, decisions and guardrails.
- `GETTING_STARTED.md` + `FIRST_SESSION_PROMPTS.md` — created by `just init` for your first project.

Why it works the way it does:

- [docs/talks/spec-driven-template.md](docs/talks/spec-driven-template.md) — the same argument as a 30/40-minute talk plan, with a sourced fact sheet for every number.
- [docs/decisions/INDEX.md](docs/decisions/INDEX.md) — the template's own decision records (DEC-001…).
- [PROJECTS.md](PROJECTS.md) — real projects built with this template.
- [docs/blog/](docs/blog/) — posts on the what, why, and what got built (drafts).
- [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) — what it doesn't do.

Reference:

- [CHANGELOG.md](CHANGELOG.md) — what exists, version by version (the reliable record).
- [docs/ROADMAP.md](docs/ROADMAP.md) — the backlog, with the reasoning behind unbuilt work. Proposals, not features.
- [SECURITY.md](SECURITY.md) — trust model, secret hygiene, reporting.
- [CONTRIBUTING.md](CONTRIBUTING.md) — design principles and the dev loop, if you want to extend the template.

## What ContextCore concepts this template uses

This template is philosophically aligned with [ContextCore](https://github.com/neil-the-nowledgeable/contextcore) — the same vocabulary (`task.*`, `insight.*`, `guidance.*`, `handoff.*`, `project.*`), the same artifact model, the same forward-compatibility to OTel-based observability. But it requires no infrastructure — everything is markdown files until (and only if) you graduate to the full ContextCore stack.

See `docs/CONTEXTCORE_ALIGNMENT.md` for details (created by `just init`).

## License

Do whatever you want with this template.
