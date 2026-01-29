---
name: "git-commit"
description: "Standardizes Git commits (status check, staging, commit, push). Invoke when user says 提交/commit/push or asks to按规范提交."
---

# Git Commit

## Goal

Make commits predictable and reviewable by following a repeatable sequence before committing and pushing.

## When to Invoke

- User says “提交 / commit / push”
- User asks “按规范提交 / 按照 skill 规范提交”
- After completing a code change and a commit is expected

## Procedure

1. Check repository state
   - `git status --porcelain`
   - If there are submodules: `git submodule status`
2. Decide what to stage
   - Prefer staging only the intended files
   - Use `git add <paths>` (avoid `git add .` unless changes are small and clearly scoped)
3. Validate before commit (only if relevant commands exist in the repo)
   - Run lint and typecheck scripts if present (e.g. `npm run lint`, `npm run typecheck`)
   - Run tests if a test command exists
4. Commit
   - Use a descriptive message in present tense
   - If the change is a submodule update, include the submodule name in the message
5. Push
   - Push current branch and set upstream if needed

## Commit Message Guidelines

- Prefer: `Add/Update/Fix/Refactor <scope>: <what changed>`
- Examples:
  - `Add game_agent submodule`
  - `Fix build: update tsconfig paths`
  - `Refactor auth: simplify token refresh`

## Submodule Notes

- A submodule commit records:
  - `.gitmodules` changes (URL/path)
  - The submodule pointer (mode `160000`)
- If SSH (port 22) is blocked, using HTTPS URL is acceptable for cloning.
