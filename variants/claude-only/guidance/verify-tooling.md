# Verify-phase tooling (optional)

This template keeps the **Verify** cycle convention-driven: a spec ships
when its acceptance criteria are met, tests pass, and there's no decision
drift (see `AGENTS.md` → "During verify"). Nothing here is required — the
template runs with zero external dependencies. This note records external
tools worth reaching for *when a project's needs outgrow the defaults*.

## LineSpec — protocol-level integration tests

<https://linespec.dev>

LineSpec's testing half is a good fit for the Verify phase when an app has
real wire traffic that's painful to cover with in-process mocks. It
intercepts MySQL, PostgreSQL, HTTP, Kafka, gRPC, and Redis at the protocol
level and drives them from a language-agnostic DSL (`RECEIVE` / `EXPECT` /
`VERIFY` / `RESPOND`), so the tests don't live inside your application code.

**Consider it when:**
- A spec's acceptance criteria are about *protocol behavior* — request/
  response shapes, DB queries issued, message contracts — not just return
  values.
- You're verifying across a service boundary and mocks keep drifting from
  the real wire format.
- The implementer and the app are in different languages and you want one
  test suite that doesn't care.

**Skip it when:**
- Unit / integration tests in the app's own framework already cover the
  criteria. Don't add an infra dependency you don't need.
- The app has no meaningful DB/HTTP/queue traffic to assert on.

**Adoption is project-level, not template-level.** If you decide to use it,
record that as a `DEC-*` in `/decisions/` (with `affected_scope` for the
test paths), add `linespec` to the project's setup docs, and reference the
`.linespec` files from the relevant spec's acceptance criteria. Keep it out
of the template defaults so a fresh clone stays dependency-free.

## Decision auditing — already native

LineSpec's *other* half (Provenance Records — documenting and enforcing
architectural decisions) overlaps with what this template already does in
`/decisions/`. Rather than depend on the binary, the template ships a
native, zero-dependency equivalent:

```bash
just decisions-audit             # structural lint + scope-conflict warnings
just decisions-audit --changed   # which decisions govern your pending changes
```

The optional `affected_scope:` glob list in a decision's front-matter is
what powers the scope checks. See `/decisions/_template.md`. If you later
want commit-time enforcement, wire `just decisions-audit --changed` into a
pre-commit hook.
