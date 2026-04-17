# CLAUDE.md

## Git commit/push rules

- When committing and pushing, stage and commit **all changes** in the target repository. Do not cherry-pick individual files unless explicitly asked.
- **Do not touch directories that belong to other repositories** (e.g. git submodules). Only commit changes within the repository you are working in.
- **Never create a new branch** for committing or pushing. Always commit and push to the **current working branch**.
