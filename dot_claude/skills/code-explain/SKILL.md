---
name: code-explain
description: >
  Explains code to the user concisely using ASCII diagrams and tables where helpful.
  Use when the user asks to understand, review, or explain code — e.g. "explain this
  function", "review our feed code", "how does X work?", "walk me through this file".
  Spawns an Explore agent to map and summarize the codebase first (skip if the codebase
  is already well understood from prior context), then reads the relevant parts directly
  and explains them back concisely.
---

# Code Explain

## Workflow

### 1. Decide whether to explore first

Skip the Explore agent if:
- The relevant files have already been read in this conversation
- The user pointed at a specific file/function with no surrounding context needed

Otherwise, spawn an Explore agent in the background with a prompt like:

> "Map the structure of [area]. For each file, give a 1–2 sentence summary of what it
> does. Note key types, traits, and how files relate to each other. Be concise."

### 2. Read the specific code

While the Explore agent runs (or immediately if skipping), read the exact files/lines
the user is asking about.

### 3. Explain concisely

Reply with a focused explanation. Default to prose with inline code references
(`file.rs:42`). Add ASCII diagrams or tables only when they make structure or flow
meaningfully clearer than prose alone.

**ASCII diagrams are useful for:**
- Data flow / call chains
- State machines
- Type hierarchies or ownership relationships
- Thread/task boundaries

**Tables are useful for:**
- Comparing variants of an enum or trait implementors
- Listing fields with types and meanings
- Summarizing bounds/constraints side-by-side

Keep responses short. If the user wants more depth on a sub-topic, they'll ask.
