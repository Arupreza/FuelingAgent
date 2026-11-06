---
name: graphify
description: Answer cross-repo structural questions about this workspace by querying the dependency graph instead of grepping - who consumes a DTO, who publishes or handles a routing key, what breaks if a contract changes, what a repo pins, which service handles a job variant, what a class does and who calls it. Use BEFORE exploring with grep/find whenever a question spans more than one repo or asks "who/what else touches this".
---

# graphify — query the workspace instead of reading it

No single repo answers a cross-repo question, and grepping for one burns tens of thousands
of tokens of context across many rounds. `graphify` answers the same questions from a
pre-built graph in one call.

**Binary:** `<path to your graphify clone>/graphify`
**Summary doc:** `<workspace root>/ARCHITECTURE_GRAPH.md` (~7k tokens, read once)

## Reach for this first when the question is

| Question | Command |
|---|---|
| "What is X and who uses it?" | `graphify explain X` ← **start here** |
| "Who consumes this DTO?" | `graphify contract JobPostsCreatePayload` |
| "Who publishes/handles this routing key?" | `graphify key orders.events.completed` |
| "What breaks if I change this?" | `graphify impact JobPayload` |
| "Who calls this?" | `graphify callers SendEmailUseCase --depth 2` |
| "What version does X pin of Y?" | `graphify deps my-service-worker` |
| "What routes does this service expose?" | `graphify routes my-service-api` |
| "A user reported this error message" | `graphify trace "<the message>"` ← works on rendered text |
| "Why didn't this fire?" | `graphify explain X` — see its **guards** |
| "What triggers this code?" | `graphify explain X` — **triggered by** (message keys and crons; not HTTP) |
| "How does this workflow advance?" | `graphify workflow Republish` |
| "What columns does this table have?" | `graphify table Orders` |
| "Is this tested?" | `graphify explain X` — see **tested by** |
| "How does X work here?" (convention) | `graphify know <topic>` ← **before grepping** |
| "Where does this status get set?" | `graphify status OrderStatus` |
| "Are the docs still true?" | `graphify docs --drift-only` — **structured claims only** |
| "Where is anything called X?" | `graphify find Account` |
| "Is the graph trustworthy right now?" | `graphify doctor` |

Add `--json` before the subcommand for machine-readable output:
`graphify --json key orders.events.completed`.

## Use it BEFORE touching a shared contract

Before modifying anything that crosses a service boundary — a DTO, an event payload, a
routing key, a Ktor resource, a sealed union — orient first, then read only what the tool
surfaced:

1. `graphify explain <symbol>` to see what it is, what triggers it, what stops it, and who
   depends on it.
2. `graphify know <topic>` for the established constraints and the gotchas already paid for.
3. `graphify impact <symbol>` to see the blast radius **across repos** before writing an
   edit. This workspace has cross-repo contracts with independent version pins; a change
   that compiles locally can still break a downstream repo.
4. Read only the files those queries name. Do not load unreferenced module trees.

`graphify brief <symbols...> --budget 1200` produces a compact, paste-ready orientation
block — useful when handing work to a fresh session, and generated from the graph so it
cannot drift the way a written note does.

## How to use it well

- **`explain` is the orienting move.** It returns the declaration, its KDoc, fields with
  their documentation, dependencies, callers, routing keys in and out, and what it handles —
  the whole briefing in one call. Run it before opening any file.
- **Ambiguous names are answered, not guessed at.** Names like `Account`, `Order` or `Buyer`
  routinely mean different things in different services; the tool lists every match with its
  repo and file so you pick deliberately.
- **An empty result is a finding.** `callers X` returning nothing means X has no call sites —
  that is how an unwired repository stub gets identified.
- **Freshness is automatic.** Every query stats the source tree (~110ms) and rebuilds if it
  has changed, printing what changed. Pass `--stale-ok` to skip the check when you know the
  tree has not moved.

## What it does NOT know

`trace` matches a message a user quoted — values already substituted — back to the code
that emits it, plus the guards on the way there. It handles Kotlin string templates
(`${expr}`, bare `$ident`, SLF4J `{}`) and `+` concatenation.

Two limits worth knowing: it indexes **Kotlin only** — a message from the app or the
Python vision service will not be found — and about 8% of messages have no literal run
long enough to anchor on, so a miss does not prove the message is absent.

It reads code, it does not run it. It knows the guards that *can* stop a use case, not which
one actually fired for a given request — for that you still need logs and traces.

Guards are labelled by exit scope: a bare `return` stops the work, `return@mapNotNull` only
skips one item. Do not read the second as "it stopped here".

## If it looks wrong

`graphify doctor` self-checks the invariants that would make the graph untrustworthy (parse
health, publish-site coverage, cross-repo edge legality) and separately reports drift it
merely observed (artifacts pinned at several versions, routing keys with a missing end). It
exits non-zero only on a real failure.

## If the binary is missing

Set the path above to your graphify clone. If it does not exist, the tool was never set up on
this machine — say so rather than falling back to grepping the whole workspace silently,
because that is the expensive behaviour this skill exists to replace.

If a query returns nothing where you expected results, check `graphify root` first: the
workspace root is *discovered*, and a wrong one produces an empty graph rather than an
error. `GRAPHIFY_ROOT=/path/to/workspace` overrides it.
