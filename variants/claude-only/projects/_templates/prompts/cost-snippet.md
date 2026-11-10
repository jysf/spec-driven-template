# Cost-session snippet for cycle prompts (paste into build / verify / ship prompts)

> Replaces the old "append a cost session with **null numerics**" line that let
> cost tracking silently go empty (AGENTS.md §4 / docs/cost-tracking.md). Do NOT
> write `null` for build/verify cycles.

**For a build or verify prompt** (the cycle runs as a metered subagent):

```
Append your cycle's entry to the spec front-matter `cost.sessions` with:
  - cycle: <build|verify>
    agent: <the model you ran as>
    interface: claude-code
    basis: <leave null here>            # set with the number: transcript | agent-result
    tokens_total: <leave null here>     # the ORCHESTRATOR fills the real number
    estimated_usd: <leave null here>    # from the Agent result at ship
    duration_minutes: <leave null here>
    recorded_at: <YYYY-MM-DD>
    notes: "<one line>"
Do NOT invent token numbers. The orchestrator records the real tokens_total /
duration / estimated_usd from your Agent result during ship bookkeeping.
(If you run this cycle interactively instead of as a subagent, run `/cost` and
write the real numbers here yourself.)
```

**For the orchestrator's ship bookkeeping** (this is where real numbers land):

```
For each metered cycle (build, verify), write the real values into cost.sessions:
  tokens_total    = the cycle's transcript, measured per docs/cost-tracking.md
                    "Measuring a cycle" (dedupe by message.id, max output per
                    message, include the subagents/ dir, exclude your own
                    orchestrator transcript)                 → basis: transcript
                    If you only have the Agent result, use its subagent_tokens
                    → basis: agent-result. The two are different quantities
                    (measured 26× apart); never mix them unlabelled.
  agent           = the model that actually ran (message.model in the
                    transcript), not the one the prompt or tier_map named
  duration_minutes= round(duration_ms / 60000)
  estimated_usd   = priced per component at that model's list rates, cache
                    reads at 0.10× input and cache writes at 1.25× (5-minute)
                    or 2× (1-hour); the formula is in docs/cost-tracking.md
                    "Pricing". Not tokens_total × one rate: that overstated
                    2.6–14.7× on cache-heavy cycles.
Leave design/ship (orchestrator main-loop) numerics null with a
"main-loop, not separately metered" note.
Compute cost.totals: tokens_total = sum of non-null sessions (use 0, not null,
for the placeholder), estimated_usd = sum, session_count = number of cycles.
Then `just cost-audit` must pass before the spec is considered shipped.
```
