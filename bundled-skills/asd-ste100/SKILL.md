---
name: asd-ste100
description: Write technical documentation in ASD-STE100 Simplified Technical English - short sentences, one meaning per word, active voice, no gerunds, one instruction per step. Use when writing or editing a README, runbook, setup or install guide, API or module docs, release notes, a CHANGELOG entry, docstrings, error and log messages, UI copy, a spec or a handover document, and whenever the reader may not be a native English speaker. Also use when asked for "simplified technical english", "STE", "ASD-STE100", "controlled language", or "plain technical English".
---

# ASD-STE100 — Simplified Technical English

A controlled language for technical writing. Issue 9 (January 2025) is the current
version: 53 writing rules and a dictionary of approved words. It is maintained by the
Simplified Technical English Maintenance Group (STEMG) at <https://asd-ste100.org>,
and the official text is free to request there.

Written for aerospace maintenance manuals, read by people who work in a second
language. The same rules make software documentation easier to read, easier to
translate, and harder to misread.

**This file holds the rules, not the dictionary.** The approved-word list is part of
the copyrighted specification. Do not try to recite it. Apply the rules below, and
when a word choice matters, say which word you chose and why.

## The rules that change what you write

**Words**
- One word, one meaning. Pick the meaning and keep it. `follow` means "come after",
  so write "obey the procedure", not "follow the procedure".
- One meaning, one word. Do not vary a term for style: `install` is not sometimes
  `set up`, sometimes `provision`, sometimes `deploy`. The same thing keeps the same
  name on every page.
- Keep technical names and technical verbs. A domain term (`epitope`, `checkpoint`,
  `healthcheck`, `commit`) is approved by being the real name of the thing.
- No vague qualifiers: `appropriate`, `relevant`, `as necessary`, `if required`,
  `various`, `several`, `simply`, `just`. Say the condition or delete the word.
- Do not use a noun as a verb (`to onboard`, `to action`, `to architect`).

**Verbs and voice**
- Active voice. The thing that acts is the subject: "The hook rebuilds the report",
  not "The report is rebuilt by the hook".
- Passive is allowed only where the actor is unknown or irrelevant, and in a warning
  where the action matters more than the actor.
- Simple tenses: present, past, future. Not `has been being`, not `will have been`.
- No gerunds or participles as nouns or modifiers. Not "Running the tests requires
  torch" but "To run the tests, you need torch". Not "the failing test" but "the test
  that fails".
- Use the infinitive to give a purpose: "To restore the database, run this command."
- Keep the articles. `the` and `a` are not noise: "Open config file" is ambiguous
  about which one.

**Sentences**
- One instruction per sentence. Two actions are two sentences, or two steps.
- Procedural sentence: 20 words or fewer. Descriptive sentence: 25 words or fewer.
- One topic per paragraph. A descriptive paragraph holds 6 sentences or fewer.
- Put the condition first: "If the cache is cold, the run fails." The reader must
  know whether a sentence applies to them before they read what it does.
- No more than three noun words in a row. "surrogate checkpoint pool row count" is
  unreadable; break it with a preposition: "the number of rows in the surrogate's
  design pool".
- Say the same thing in the same order every time. Parallel steps read in parallel.

**Procedures**
- Write a step as a command: "Restore the dump." Not "The dump should be restored"
  and not "You may want to restore the dump".
- Number the steps that must happen in order. Bullet the ones that do not.
- One step does one thing the reader can finish and check.

**Safety and consequence**
- A warning comes BEFORE the step it protects, never after.
- Say the consequence plainly: "This deletes the cluster. The data cannot be
  recovered." Not "Please note that this operation may be destructive."
- A condition that loses data, costs money, or cannot be undone gets its own
  sentence. Do not bury it in a clause.

**Punctuation**
- Full stops and commas. Avoid the semicolon, the dash as a connector, and the
  slash (`and/or`, `enable/disable`) — say which one you mean.
- No contractions in reference documentation: `do not`, not `don't`.
- No parentheses holding a second thought. Make it a sentence or delete it.

## How to apply it

1. Write the content first. Get it right, then make it simple — not the other way
   round.
2. Read each sentence and ask: how many instructions, how many words, which voice.
3. Fix the longest sentence first. Length is the rule that is broken most often and
   costs the reader most.
4. Check the terms against each other, not against a dictionary: one name per thing,
   across the whole document.

## Where it does not apply

- Code, identifiers, commands, output and log lines are quoted as they are. Never
  "simplify" a command.
- Existing prose in a file you are editing: match the file's voice unless the task is
  to rewrite it. A document in two styles is worse than a document in one imperfect
  style.
- Commit messages and PR descriptions follow the repository's own convention.
- Conversational replies to your human partner. This is a documentation standard, not
  a way to talk.

## Why a software project wants this

- A reader who is tired, or reading in a second language, gets it on the first pass.
- An ambiguous instruction in a runbook is a production incident. "Restore the
  database if required" does not say who decides, or when.
- Machine translation and search both work better on one term per concept.
