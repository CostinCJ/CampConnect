# R1 — Credential & Secret Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the live Firebase Admin SDK credential exposure found in a local git stash entry,
and make an explicit, documented decision on the lower-risk client API keys sitting in public git
history.

**Architecture:** This phase is almost entirely operational (GCP Console + git surgery), not
application code. Several steps are destructive or touch external cloud state and REQUIRE your
explicit go-ahead at execution time — this plan documents exactly what will happen so you can
approve each step individually, it does not pre-authorize them.

**Tech Stack:** Google Cloud Console (IAM & Admin), git.

**Branch:** `remediation/r1-credential-hygiene` (docs-only changes in this branch; the git-stash
surgery in Task 2 operates on the repository itself, not a feature branch — see that task).

---

### Task 1: Rotate the exposed service-account key

**Files:** none (GCP Console only) — this task produces no repo diff except an optional note in
Task 3's decision doc.

- [ ] **Step 1: Identify the exact key**

Go to GCP Console → IAM & Admin → Service Accounts →
`firebase-adminsdk-fbsvc@camp-connect-4644c.iam.gserviceaccount.com` → Keys tab. Cross-reference the
key's "Created" timestamp against the git-stash commit's date (commit `f24cdc1`, branch
`feature/phase-6-llm`'s stashed index) to identify which key this is.

- [ ] **Step 2: Check for live dependents BEFORE deleting anything**

Run:
```bash
grep -rn "service-account" scripts/ functions/ 2>/dev/null
grep -rn "GOOGLE_APPLICATION_CREDENTIALS" scripts/ functions/ 2>/dev/null
```
If `scripts/migrate_to_orgs.js` or `scripts/seed_firestore.js` reference a service-account file path,
confirm with the user whether that script is still needed before deleting the key it depends on —
deleting a key a still-in-use script needs will break that script the next time it runs.

- [ ] **Step 3: Delete/disable the key — STOP AND CONFIRM WITH THE USER FIRST**

This is an irreversible action against production cloud infrastructure. Present the user with the
key's ID, creation date, and the result of Step 2, and get explicit confirmation before deleting it
in the Console.

- [ ] **Step 4: If a local admin script still needs a service-account key, generate a new one and store it OUTSIDE the repo**

Generate a new key in the Console. Save it to a path outside `D:\CampConnect` entirely, e.g.
`C:\Users\Costin\.config\campconnect\service-account.json` (never inside the project directory,
even gitignored — gitignored files still get `git add -A`'d by accident, still get force-added,
still get copied into repo zips/backups). Reference it via an environment variable in whatever
shell profile is used to run the admin scripts:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="C:/Users/Costin/.config/campconnect/service-account.json"
```

- [ ] **Step 5: Verify no service-account file is tracked in the repo**

Run:
```bash
git ls-files | grep -i "service-account"
```
Expected: no output.

---

### Task 2: Remove the unreachable stash entry from local git

**Files:** none — this operates on the local `.git` object database, not tracked files.

This task is DESTRUCTIVE to local git history (stash contents + `git gc` permanently discards
unreachable objects). Do not run Steps 2-3 without the user's explicit go-ahead given at the time,
even though this plan describes the steps in advance.

- [ ] **Step 1: Show the user exactly what exists, read-only, before touching anything**

Run:
```bash
git stash list
git stash show -p stash@{0} -- scripts/service-account.json
```
(Adjust the stash index if `git stash list` shows the relevant entry at a different position.)
Confirm with the user this is the same key identified/rotated in Task 1 before proceeding.

- [ ] **Step 2: Drop the stash entry — STOP AND CONFIRM WITH THE USER FIRST**

```bash
git stash drop stash@{0}
```

- [ ] **Step 3: Expire reflog and garbage-collect to actually purge the unreachable blob — STOP AND CONFIRM WITH THE USER FIRST**

```bash
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

- [ ] **Step 4: Verify the blob is gone**

Run:
```bash
git rev-list --objects --all | grep -i "service-account"
```
Expected: no output. (Note: this only proves it's gone from *this* local clone. If this repo was
ever cloned/backed up elsewhere before this step, the key remains exposed there — Task 1's key
rotation is what actually neutralizes the risk regardless of how many copies of the old key exist.)

---

### Task 3: Decide on the public client API key exposure

**Files:**
- Create: `docs/superpowers/plans/r1-decision-log.md`

The client-side Firebase config (`lib/firebase_options.dart`, real values) was committed in
`origin/main` commit `bb19600` and remains reachable from `origin/main` today, even though a later
commit (`1b0a9ce`) replaced the tracked file with a gitignored template. Firebase client API keys
are not secrets in the traditional sense (Google's own guidance: they identify the project, they
don't authorize access — Firestore/Storage rules are the actual gate, and this review's security
pass confirmed those rules are solid), but they are still routinely flagged by scanners and are
somewhat awkward to have in history for a repo tied to a public thesis.

- [ ] **Step 1: Present the tradeoff to the user and record the decision**

Create `docs/superpowers/plans/r1-decision-log.md`:
```markdown
# R1 Decision Log

## Public client Firebase config in git history (commit bb19600)

**Options considered:**
1. Accept the risk — client keys aren't authorization secrets; rules are the real gate (verified
   solid by the 2026-07-05 security review). No action.
2. Rewrite history with `git filter-repo --path lib/firebase_options.dart --invert-paths`, then
   force-push. Requires coordinating the two open remote branches
   (`claude/production-readiness-audit-2mstjl`, `claude/production-readiness-audit-rmwacl`) and any
   other local clones, since this rewrites commit hashes on `main`.

**Decision:** [fill in after discussing with the user — this file intentionally ships with this
one placeholder, since the decision is the user's to make, not a task an engineer can complete
unilaterally]

**Decided by:** [user] on [date]
```

- [ ] **Step 2 (only if the user chooses option 2 — do not execute without a separate, explicit go-ahead in its own session):**

```bash
# On a FRESH clone, never the working copy:
git clone --mirror https://github.com/CostinCJ/CampConnect.git campconnect-mirror
cd campconnect-mirror
git filter-repo --path lib/firebase_options.dart --invert-paths
# Review the result before pushing:
git log --oneline | head -20
# Only after explicit confirmation:
git push --force --all
git push --force --tags
```
Then every other clone (including this working directory) must be re-cloned or hard-reset to the
rewritten history — coordinate this explicitly, it is not a step to run silently in the background.

- [ ] **Step 3: Commit the decision log**

```bash
cd /d/CampConnect
git add docs/superpowers/plans/r1-decision-log.md
git commit -m "docs: record R1 decision on public client Firebase config exposure"
```
