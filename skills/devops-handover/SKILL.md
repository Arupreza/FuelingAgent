---
name: devops-handover
description: Audit a codebase the way the DevOps or platform team who must deploy it will - before handing it over. Finds what sends a deliverable back - hardcoded paths, undeclared system dependencies, credentials with defaults, a healthcheck that is green before the service is ready, no rollback, a runbook whose commands do not run. Use before shipping a release, a delivery artefact or a repository to operations, and when someone asks whether something is ready to hand over.
---

# DevOps handover audit

For a developer who writes the code but does not operate it.

**The question is not "does it work on my machine". It is: can someone who has
never seen this repository run it, tell when it is broken, and fix it at 3am —
without asking me?**

Work through the sections. For each item answer **PASS**, **FAIL** or **N/A**,
and give the evidence: a command and its output, a file path, a line number.
An item with no evidence is a FAIL — those are the ones that get assumed.

End with one verdict: **GO**, **CONDITIONAL GO** (list what must be fixed
first), or **BLOCK**.

An N/A is legitimate, but write the reason next to it. "No rollback, because
this is a stateless read-only service redeployed from scratch" is an answer.
Silence is not.

## 1. It stands alone

- [ ] Does it run on a machine holding none of the author's local state? No
      path into a home directory, an external disk, a personal database, a
      local model cache.
- [ ] Is every dependency declared AND pinned — including the ones a package
      manager cannot install? A system binary missing on PATH fails at the
      first real call, long after a successful install.
- [ ] Are container images pinned by digest rather than a moving tag? A tag
      that shifts between the author's test and the deploy produces the
      hardest class of bug to reproduce.
- [ ] Does a build or install work offline, or is it silently fetching from
      the network at deploy time?

## 2. Configuration and secrets

- [ ] Is every credential read from the environment with **no default**? A
      shipped default is a credential published in the repository, and
      "change it before production" is a sentence, not a control. Prefer a
      form that refuses to start over one that falls back.
- [ ] Does it fail at **startup** on missing or malformed config, not at first
      use, an hour in, on one code path?
- [ ] Is there an example config with placeholders only, and is the real one
      ignored by version control AND outside any directory mounted into a
      container?
- [ ] Has git **history** been scanned, not just the working tree? A removed
      secret is still in the history, and still valid until rotated.

## 3. Start, verify, stop

- [ ] Is there one documented command that brings it up?
- [ ] Does "healthy" mean **ready to serve**, or only "the process is
      listening"? A service reporting green while it still warms a cache or
      builds an index will be used, and will be slow for reasons nobody can
      see from outside.
- [ ] Is there a command that answers "is this working?" which they run
      themselves — rather than a paragraph describing what to look for?
- [ ] Does it shut down cleanly on SIGTERM, and is a restart safe? No
      half-written state, no repeating an expensive import.

## 4. Data and migrations

- [ ] Is the schema versioned, and can they ask the running system which
      version it is on?
- [ ] Is every migration safe to re-run?
- [ ] Is there a restore path, and has it been tested **from the artefact that
      actually ships**, into a clean volume? "A backup exists" is not a
      restore path until someone has restored it.
- [ ] Is the artefact's checksum recorded somewhere other than beside the
      artefact? A hash shipped next to a file certifies nothing against
      tampering — put it in version control.

## 5. Failure and rollback

- [ ] What does a failed deploy look like, and what do they do about it?
- [ ] Can they roll back, and has that been tried rather than assumed?
- [ ] What happens when a dependency is unreachable — does it fail fast, retry
      forever, or corrupt something?
- [ ] Do error messages say what to do, or only what went wrong?
- [ ] Are the resource limits known: memory ceiling, disk growth, what happens
      when the disk fills?

## 6. The runbook

- [ ] Can someone follow it **without the author**? The test is not whether it
      reads well — it is whether the commands run as written, copied and
      pasted, in order.
- [ ] Does it state the resources needed: disk, memory, cores, and how long a
      first start takes before anything looks healthy?
- [ ] Does it list the ports and which interface each binds to? Publishing on
      all interfaces is a frequent accident, and on some container runtimes it
      bypasses the host firewall.
- [ ] Does troubleshooting cover the failures that actually happened in
      testing, with the error text they will see?

## 7. Ownership

- [ ] Who owns this, and who is called out of hours?
- [ ] What should be monitored, and which threshold means "wake someone"?
- [ ] What is the backup policy once it is running, and who runs it?
- [ ] What is the secret-rotation path, and does rotating require a restart?
- [ ] Where do the logs go, and do they contain anything that must not be
      retained?

## Running the audit

Read the code, then **verify** — most of this is checkable, not a matter of
opinion. Adapt the patterns to the stack:

```bash
# paths that only exist on one machine
grep -rnE '"/home/|"/Users/|"/mnt/|"/media/|[A-Z]:\\\\' --include='*.py' \
     --include='*.js' --include='*.ts' --include='*.go' --include='*.sh' .

# credentials with a literal default
grep -rnE '(password|secret|token|api[_-]?key)\s*[:=]\s*["'"'"'][^$<{]' .

# history, not just HEAD
git log -p --all -S 'PRIVATE KEY' | head
git log --all --format='%H' | head -50 | xargs -I{} git grep -lI 'password *=' {} 2>/dev/null | head

# container images on a moving tag
grep -rn 'image:' --include='*.yml' --include='*.yaml' . | grep -v '@sha256:'

# what binds to every interface
grep -rnE '0\.0\.0\.0|"\s*[0-9]+:[0-9]+"' --include='*.yml' .
```

Then run the test that subsumes most of the list:

> **Unpack the deliverable somewhere clean, follow the runbook literally, and
> change nothing.** Where you reach for knowledge that is not written down,
> that is the finding.

Do it on a machine without the author's environment if one is available, and
in a container if not.

## Why the evidence rule matters

Every item here exists because a real handover failed on it. The pattern is
consistent: the failures are never the hard parts of the system. They are a
path that happened to exist, a default nobody meant to ship, a checksum file
holding an absolute path, a port colliding with another service, a copy of the
tests that had gone stale, a healthcheck that went green before the data was
loaded.

None of those are visible by reading the code. They are visible by running it
somewhere that is not where it was written.
