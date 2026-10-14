---
name: fleshing-out
description: Use before planning, designing or building anything non-trivial, when asked to grill, interview or flesh out a plan, or when a task needs open decisions settled first. Interviews the user until every decision is settled. Skip small, fully specified or already agreed work.
---

# Fleshing out

Interview the user relentlessly until you reach a shared understanding of the subject.

## The design tree

- Map the subject as a **design tree**: every decision branches into the decisions that hang off it.
- Number each decision D1, D2 and so on when it enters the tree, and keep that number for the whole interview. The user replies by it, so numbers never restart or change.
- The **frontier** is every decision whose prerequisites are settled. These are the questions you can ask now without guessing at answers you haven't heard.
- Finding facts is your job, never the user's: don't ask the user for anything you could look up yourself.
- The decisions are the user's. Put each one to them.
- Send a subagent on a long lookup, and ask the rest of the frontier meanwhile. Only the questions that depend on its result wait.

## Session file

Keep a record of the interview in a markdown file in the session's scratchpad: the design tree with decision numbers, each answer in the user's words, and the facts you found. Update it after each round. When earlier answers are no longer in your context, read them from the file.

## Rounds

1. Recompute the frontier. Each answer settles decisions and unblocks the ones that depended on them. Check: every frontier decision has its prerequisites settled.
2. Rank the whole frontier, including decisions left over from earlier rounds. Put first the decisions that the most other decisions depend on. Break ties by how hard the decision is to reverse. Check: the ranking includes every frontier decision.
3. Pick the top 4. Skip a decision that depends on another picked one, and take the next instead. Check: no picked decision depends on another picked one.
4. Post the round in one message, in the round format below. Give each question your recommended answer, and word it so "yes" accepts the recommendation. Check: every question has a recommendation.
5. Wait for the user's answers. Treat a question the user skips as accepting your recommendation. Check: every question in the round is answered or accepted by default.
6. Repeat from step 1 until the frontier is empty. Check: every branch is visited and nothing is silently assumed.
7. Act on the subject only after the user confirms you share one understanding. Check: the user has confirmed.

## Round format

Open each round with a tree of the decisions so far, marked by status:

- ✅ answered, with the answer in a few words
- ☑️ accepted by default, because the user skipped it
- ❓ asked in this round
- ⏳ waiting on a parent, naming the decision it waits for
- 🔍 a fact being looked up

Show every decision with its number. Collapse a fully answered branch into its top decision. For example:

```markdown
### Round 3 · asking 3 of 5 open decisions

**Tree**
- ✅ D1 Scope: local git commits only
- ✅ D2 Repo roots: config file
  - ❓ **D4** Scan depth
  - ⏳ D9 Symlinked repos *(after D4)*
- ☑️ D3 Window: previous working day to now
  - ❓ **D7** Output layout
    - ⏳ D10 Clipboard copy *(after D7)*
- ❓ **D8** Failure handling
- 🔍 Language *(looking it up)*

---

**D4 · Scan depth**
How deep should the tool search each root for repos? Deeper finds nested repos but slows every run and can wander into `node_modules`.

> ➡️ **Recommended:** 3 levels, stop descending at the first `.git`. That covers `~/code/work/<org>/<repo>` without crawling dependencies.

**D7 · Output layout**
…

---

*Reply by decision number. Skip a question to accept its recommendation, or write your own answer.*
```
