---
name: ship
description: Update docs, commit, create PR, monitor CI and reviews, address feedback, merge, review post-deploy AI analysis
user-invocable: true
argument-hint: "[optional PR number to resume monitoring]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
---

# Ship — Commit, Monitor, Fix, Merge

End-to-end workflow: update documentation, commit, create PR, monitor CI
and code reviews, address feedback, and merge when everything passes.

If `$ARGUMENTS` contains a PR number, skip to the monitoring phase for
that PR.

## Phase 1 — Update Documentation

Before committing, review all staged and unstaged changes to understand
what was modified, then update:

1. **CLAUDE.md** — If any CI/CD pipelines, hooks, skills, conventions,
   or project structure changed, update the relevant sections.
2. **README.md** — If workflows, SCPs, architecture, or tooling changed,
   update the relevant sections (tables, structure tree, descriptions).
3. **docs/adr/** — If a significant architectural decision was made
   (new pattern, new tool, structural change), create or update an ADR.
4. **MEMORY.md** — Update project memory at
   `$HOME/.claude/projects/-Users-gamaware-Documents-Repos-personal-aws-organization-governance/memory/MEMORY.md`
   if there are new gotchas, patterns, or preferences learned.
5. **accepted-findings.md** — If SCP policy files were modified, update
   `terraform/scps/accepted-findings.md` to reflect changes (e.g., move
   items from "To Fix" to "Fixed" when bugs are resolved).

Only update files where changes are actually needed. Do not update docs
for trivial changes.

## Phase 2 — Commit and Push

1. Stage all changes (including doc updates from Phase 1).
2. Write a conventional commit message summarizing all changes.
3. Push to the current feature branch.
4. Create a PR if one does not exist yet. Use the commit message as
   the PR title. Include a summary and test plan in the body.

## Phase 3 — Monitor CI

Poll CI status using `gh pr checks <number>` every 30 seconds until
all checks complete (pass, fail, or skip). Report the final status.

If any check fails:

1. Read the failure logs with `gh run view <id> --log-failed`.
2. Diagnose and fix the issue.
3. Commit and push the fix.
4. Return to monitoring.

## Phase 4 — Monitor Code Reviews

Check for review comments from CodeRabbit and Copilot:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments
gh api repos/{owner}/{repo}/issues/{number}/comments
```

If CodeRabbit is rate-limited, wait for the timeout period then trigger
with `gh pr comment <number> --body "@coderabbitai review"`.

For each review comment:

1. Read the comment carefully.
2. Check if the comment is stale (already fixed in a later commit) by
   reading the current file state. Dismiss stale comments.
3. If the comment is valid, fix the issue, commit, and push.
4. After fixing, re-monitor CI (return to Phase 3).

After all fixes are pushed and the incremental review passes, resolve
stale CodeRabbit threads in bulk:

```bash
gh pr comment <number> --body "@coderabbitai resolve"
```

For Copilot and any remaining unresolved threads, resolve via GraphQL:

```bash
# Get all unresolved thread IDs
gh api graphql -f query='
  { repository(owner: "gamaware", name: "aws-organization-governance") {
    pullRequest(number: <NUMBER>) {
      reviewThreads(first: 100) {
        nodes { id isResolved }
      }
    }
  }}'
```

Then for each unresolved thread ID:

```bash
gh api graphql -f query='
  mutation { resolveReviewThread(input: {threadId: "<ID>"}) {
    thread { isResolved }
  }}'
```

Copilot auto re-reviews on push ("Review new pushes" ruleset is enabled),
but may duplicate previously resolved comments. After the final review
passes, resolve all remaining threads in bulk.

## Phase 5 — Merge

Once ALL of the following are true:

- All CI checks pass
- CodeRabbit review has no unaddressed comments
- Copilot review has no unaddressed comments

Then merge:

```bash
gh pr merge <number> --squash --admin --delete-branch
```

Pull main locally after merge:

```bash
git checkout main && git pull
```

Report the merge commit and confirm the branch was deleted.

## Phase 6 — Post-Deploy Analysis (terraform changes only)

Skip this phase if the PR did not modify any files under `terraform/`
or `.github/scripts/ai-deployment-analysis.sh`.

After merge, the terraform-cicd workflow runs automatically. Wait for
it to complete, then review the AI analysis artifact:

```bash
# Find the deploy run triggered by the merge
gh run list --branch main --limit 3 --json databaseId,name,status \
  --jq '.[] | select(.name | startswith("Terraform plan"))'

# Watch it complete
gh run watch <run-id> --exit-status

# Download and read the AI analysis
gh run download <run-id> -n ai-deployment-analysis -D /tmp/ai-analysis
cat /tmp/ai-analysis/ai-analysis.md
```

Review the analysis output:

1. **"No new findings"** — Done. Report to user and finish.
2. **New findings reported** — For each new finding:
   - Assess severity and validity.
   - Present findings to the user with a recommended disposition
     (fix, accepted-risk, wont-fix, to-fix).
   - After user confirms, update `terraform/scps/accepted-findings.md`
     with the triage decisions.
   - If any items are triaged as "to-fix" with P1/P2 priority, ask
     the user if they want to fix them now in a follow-up PR.
   - Commit and push the accepted findings update as a new PR.
3. **Regressions detected** (fixed item reappeared) — Flag immediately
   to the user. These indicate a revert or merge conflict that undid
   a previous fix.

## Rules

- Never suppress lint violations — fix them.
- No AI attribution in commits.
- Conventional commit messages required.
- SKIP=zizmor is acceptable for pre-existing zizmor warnings during commit.
- CodeRabbit may hit hourly rate limits — wait and retry.
- Copilot comments may be stale after fix commits — verify current file state.
- Copilot auto re-reviews on push ("Review new pushes" ruleset is enabled).
- Copilot may duplicate comments on re-review — even for resolved issues.
- CodeRabbit auto-reviews incrementally on every push (up to 5 commits,
  then pauses). Use `@coderabbitai review` to resume after pause.
- CodeRabbit does NOT auto-resolve its threads — use `@coderabbitai resolve`
  after fixes are confirmed.
- Neither reviewer auto-resolves threads. Use `@coderabbitai resolve` for
  CodeRabbit and GraphQL `resolveReviewThread` for Copilot/all threads.
- Use `--admin` to bypass branch protection for merge.
