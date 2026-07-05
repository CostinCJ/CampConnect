# R1 Decision Log

## Public client Firebase config in git history (commit bb19600)

**Options considered:**
1. Accept the risk — client keys aren't authorization secrets; rules are the real gate (verified
   solid by the 2026-07-05 security review). No action.
2. Rewrite history with `git filter-repo --path lib/firebase_options.dart --invert-paths`, then
   force-push. Requires coordinating the two open remote branches
   (`claude/production-readiness-audit-2mstjl`, `claude/production-readiness-audit-rmwacl`) and any
   other local clones, since this rewrites commit hashes on `main`.

**Decision:** Option 1 — accept the risk. No history rewrite. Firebase client API keys identify the
project but don't authorize access; Firestore/Storage security rules are the actual access-control
gate, and the 2026-07-05 security review confirmed those rules are solid. Rewriting public history
for a public thesis repo isn't worth the coordination cost (two open remote branches, any other
clones) for a key class that Google's own guidance treats as non-secret.

**Decided by:** user on 2026-07-05.
