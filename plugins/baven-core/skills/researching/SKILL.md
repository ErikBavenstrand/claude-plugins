---
name: researching
description: Use when a question needs facts gathered and checked across sources, such as the web, MCP tools, local files or code. Fits comparing options, the current state of a topic, or how something works. Writes cited, confidence-rated findings to a scratchpad file. Skip facts that one lookup settles.
---

# Researching

Research is a graph search: following a lead, such as a sub-question, URL, file or query, yields claims and new leads.

Run it in a background subagent so the caller keeps working, unless the next step waits on the answer.

Look where the owning source lives, beyond the web: local files and code, MCP tools and CLIs.

## Effort

Pick the starting level from the question, unless the user or caller sets one.

| Level | Question | Work | Researcher model | Tracing |
| --- | --- | --- | --- | --- |
| quick | widely known, or one owning source settles it | yourself, 1 round | haiku | stop at the first owning source |
| standard | specific or niche, or combines several sources | fan out, ≤2 rounds | haiku; sonnet for leads that need judgment | trace the claims the answer rests on |
| deep | hard to judge, or hard to reverse (architecture, money, security) | fan out, ≤4 rounds | sonnet; opus for the crux | trace every claim; re-read the sources the answer rests on |

Go up a level when sources conflict, confidence comes back low, or no owning source turns up.

## Process

1. Follow the leads most likely to change the answer first. Go deep on a lead the rest depend on.
2. To fan out, dispatch one `baven-core:researcher` per independent lead. Pass the lead, the question and the visited sources, and set `model` from the effort table.
3. Re-dispatch a haiku lead on sonnet when it returns no claims or only low-confidence ones. You cannot review what haiku missed.
4. Accept quoted claims as returned. Re-read sources only as the level's tracing requires.
5. Treat a conflict as a lead toward its owning source. If it stays unresolved, record both sides.
6. Stop once an owning source answers clearly, a round changes nothing, or the round limit is hit. Check: every leftover lead is under open questions.
7. Write the findings file.

## Confidence

Cite the source that owns each fact: code over docs, logs and metrics over claims, specs and official docs over blogs. A source that cites another counts as that one source.

- 🟢 high: the owning source states it, or independent sources agree.
- 🟡 medium: a reputable secondary source states it, or the owning source implies it.
- 🔴 low: one weak source, an inference, or only sources older than about 12 months on a fast-moving topic.

## Output

Write the findings file to `research-<slug>.md` in the session's scratchpad. It survives compaction, and the user or caller decides whether to keep it. Return its path, answer and confidence. When the user asked for the research directly, also show its content in chat.

Use this format, and omit empty sections:

```markdown
### <question in a few words>

> **Answer:** <1–3 sentences>
> **Confidence:** 🟡 medium — <one-line reason>

**Findings**
- 🟢 <claim> [1]
- 🔴 <claim> — <why it is weak> [2]

**Conflicts**
- ⚖️ <topic>: [1] says X, [2] says Y. Leaning X, because <reason>.

**Open questions**
- ❔ <unresolved claim, or lead left open at the limit>

---

**Sources**
1. [<title>](<URL or path>) · <date> · <primary | secondary | aggregator | forum | vendor>

*<level> · <rounds> rounds · <sources read> sources read · <researchers per model>*
```
