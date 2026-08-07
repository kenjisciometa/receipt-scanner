# CLAUDE.md

## Project structure notes

- **shift-management-app/** contains **both** a Flutter app (`flutter_app/`) and a React/Next.js web app (root-level `src/`, `package.json`, `next.config.ts`, etc.). When working in this directory, always check which codebase (Flutter or React) is relevant to the task. Do not assume it is Flutter-only.

## Git commit/push rules

- When committing and pushing, stage and commit **all changes** in the target repository. Do not cherry-pick individual files unless explicitly asked.
- **Do not touch directories that belong to other repositories** (e.g. git submodules). Only commit changes within the repository you are working in.
- **Never create a new branch** for committing or pushing. Always commit and push to the **current working branch**.
