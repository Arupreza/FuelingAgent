<!-- Drop this near the top of a project's CLAUDE.md. It is the rule that
     keeps the file from growing back. -->

**Keep this file short.** It is re-sent on every request, so it holds only what
changes a decision — hard rules, paths, commands, one-line gotchas. The
reasoning behind a rule goes in `docs/ENGINEERING_NOTES.md`; dated history goes
in `docs/WORKLOG.md`. Both are read on demand and cost nothing until then. If a
paragraph does not change what someone *does*, it belongs there, not here.
Never append a work-log entry to this file.

`bash ~/.claude/context-cost.sh` prints what a request currently carries.

<!--
Why this matters, measured 6 November 2026 on a real project:

  CLAUDE.md grew to 45,849 bytes (~11,462 tokens) and 66% of that growth
  happened in two days of appending. Splitting it cut the file to ~1,700
  tokens with NOTHING removed -- the detail moved to files that are read when
  someone needs them. Per-request context fell 15,817 -> 4,428 tokens.

What NOT to move out, however large it makes the file:

  Rules that prevent damage. "Never run git add -A here", "never walk the data
  disk", "nothing connects as the superuser". A rule you have to go and look
  up is a rule you break before you notice it applies. Those stay inline; the
  explanation of why they exist does not.

The retrieval pattern, if the notes get big:

  A project skill at .claude/skills/<name>/SKILL.md costs only its description
  in each request and loads its body when invoked -- an index in context, the
  detail fetched on demand. Point it at the notes file and tell the reader to
  grep the headings and read one section rather than the whole thing.
-->
