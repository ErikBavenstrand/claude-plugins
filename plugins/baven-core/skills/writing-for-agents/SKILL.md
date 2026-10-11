---
name: writing-for-agents
description: Invoke this skill first, before reading files, whenever the task is to create, edit or review CLAUDE.md, AGENTS.md, a skill, a subagent, a slash command, a system prompt, an LLM prompt, a tool description or instructions for another agent. It holds the rules for writing text an AI agent reads.
---

# Writing for agents

## What to include

- Write only what the model would not do by default and cannot find in code, config or `--help`: conventions, reasons, gotchas.
- Name the output's form, length and location.
- Give a rule's reason when it changes how the rule is applied.
- Give one default and one escape hatch, not a menu.
- Use exact commands where a variation breaks something, and heuristics where many outcomes are acceptable.
- Describe the current way, without history or version and date anchors.

## How to word it

- Say what to do. Name a forbidden action only when no positive form exists.
- Use the imperative mood, one instruction per sentence, under about 20 words.
- Use one term per concept, the same way every time.
- Reuse a word the model already knows instead of coining one.
- Use normal emphasis, without capitals, MUST or CRITICAL. Models apply emphasised rules too broadly.

## How to lay it out

- Number steps that run in order, and end each with a check the agent can verify.
- Put a warning before the step it applies to.
- Keep each rule in one place. Move rarely needed detail to a linked file, one level deep.
- Show one concrete example when output format matters.
- Wrap data inside a prompt, such as a document, diff or user input, in labelled tags like `<context>` or `<input>`, apart from the instructions.

After writing, check the text against each rule and fix what fails.
