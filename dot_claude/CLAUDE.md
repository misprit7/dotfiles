# Global Coding Instructions

## Before Editing
- Re-read files before editing them. Other agents or humans may have modified them since you last read them.
- If you notice a previous change you made has been undone, do not redo it unless explicitly asked. The user or another agent likely changed it intentionally.

## When Making Changes
- Think about structural implications when making large changes — consider how they affect the broader codebase.
- Always test code you write by running compile and test commands when it's obvious how to do so.
- After making large amounts of code changes, review what you wrote to make sure it still makes sense and is consistent.

## Git
- Do not add a `Co-Authored-By` / Claude trailer or any AI attribution (e.g. "Generated with Claude Code") to commit messages or PR bodies. Keep commit messages short and human-style.
- Maintain a linear history. Use rebase, not merge.
- After rebasing, use `git push --force-with-lease` (not `--force`) to push safely.
- When resolving merge conflicts, read surrounding context to understand the intent of both changes. If unclear, ask the user rather than guessing.

## Code Organization
- Do not re-export things just to shorten imports. There should be one canonical path to import each item.
- Executables and their source go in a `bin/` directory colocated with the code they are semantically related to.
- Binaries in `bin/` should have their own minimal build target, separate from the library they depend on.

## Parallelism and Efficiency
- Use subagents when useful — delegate independent research, searches, or implementation tasks.
- Run long-running tasks (builds, tests, subagents) in the background and continue working on other things in parallel.
- Start long-running tasks as early as possible since you can work on other things while they run.
