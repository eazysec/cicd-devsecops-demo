# CodeQL demo vulnerabilities — a recipe catalog, not live code

This document is the permanent, reusable part of demonstrating "CodeQL catches what Bandit
misses." The vulnerable *code* itself is deliberately **not** kept here, and never lives on a
long-lived branch — see [Why a recipe, not a branch](#why-a-recipe-not-a-branch) below. Same
principle as `scripts/generate-demo-secret.sh` for the fake-secret scenario: the method is
permanent and versioned, the live artifact is always regenerated on demand and thrown away.

## Why a recipe, not a branch

This repository is public. A long-lived branch carrying real, exploitable code (SSTI, SSRF —
both RCE/credential-theft-capable) is discoverable by anyone, forkable, and a more attractive
target for automated scanners than a branch that exists briefly around a specific demo and is
then deleted — the same reasoning already applied to `demo/fake-secret` (disposable, never
merged — see the Conference Runbook and `SECURITY.md` "Fake-secret demo"). SSRF specifically is
worth flagging: on a real AWS EC2 host, an exploitable SSRF can pivot to the instance metadata
service (IMDS) and steal the role's credentials — a materially worse outcome than "someone reads
a file," so it deserves the same discipline as the SSTI recipe below, if/when it's added.

**The pattern for using any recipe in this file**:

1. Branch fresh from `main`: `git checkout -b demo/codeql-<name>`.
2. Apply the snippet from the relevant section below.
3. Push the branch. **Do not open a PR, do not merge.**
4. Actions → `CodeQL` workflow → **Run workflow** → pick `demo/codeql-<name>` as the branch —
   `codeql.yml`'s `workflow_dispatch` trigger runs it against an arbitrary ref, no PR/merge
   needed (see [ADR 0008](adr/0008-codeql-integration.md); this is exactly why that trigger
   exists).
5. Show the resulting Code Scanning alert (Security tab, filtered to that branch/ref).
6. Contrast with Bandit: open a PR from the same branch (pr-validation.yml *does* run Bandit on
   every PR touching application code) — it passes green, silently missing the same finding.
   Close the PR **without merging**, then delete the branch:
   `git push origin --delete demo/codeql-<name>`.

Nothing from this branch ever reaches `main`, so there is nothing to clean up there afterward —
the commits become unreachable the moment the branch ref is deleted.

---

## Recipe: SSTI via `render_template_string` (CWE-94)

**Verified, not assumed**: Bandit 1.9.4's full plugin list (`bandit.core.extension_loader`) has
no check for `render_template_string`, template construction, or any form of taint tracking —
its only Jinja2-related check is `jinja2_autoescape_false` (flags an explicit
`Environment(autoescape=False)`), which is a different, unrelated risk (XSS in rendered output,
not attacker-controlled template *source*). CodeQL's `py/template-injection` (CWE-94, security
severity 9.3, high precision) is in `python-code-scanning.qls` — the suite `codeql.yml` already
runs by default, no extra `queries:` configuration needed.

**The snippet** (add to `app/routes.py`, after the existing imports add
`from flask import render_template_string, request`):

```python
def _build_greeting_template(name: str) -> str:
    return f"<p>Welcome back, {name}!</p>"


@bp.get("/greet")
def greet():
    name = request.args.get("name", "guest")
    return render_template_string(_build_greeting_template(name))
```

**Why Bandit misses it and CodeQL doesn't**: Bandit has no rule for this pattern at all (see
above) — it wouldn't catch this even with the two functions merged into one line. CodeQL's miss
would be more interesting to show if Bandit *did* have a same-line check: the indirection
(`_build_greeting_template` builds the string, `greet` calls `render_template_string` on it) is
exactly the interprocedural case CodeQL's dataflow engine is built for and a simple AST-pattern
tool structurally cannot follow across a function boundary.

**Proof of concept, non-destructive**: `GET /greet?name={{7*7}}` renders `49` instead of the
literal string `{{7*7}}` — visible, undeniable evidence the input was parsed as template syntax,
without needing to actually run the RCE gadget chain live. Narrate the escalation
(`{{ ''.__class__.__mro__[1].__subclasses__() ... }}`) verbally rather than executing it, even in
the disposable branch's own throwaway environment.

## Recipe: SSRF

Not yet written. `py/full-ssrf` (CWE-918, security severity 9.1) is also in
`python-code-scanning.qls`, confirmed during the same investigation as the SSTI recipe above —
deferred because this app has no outbound-HTTP-making code path yet to attach it to, and because
of the IMDS-pivot risk noted above, which deserves its own explicit safety write-up before a
snippet is published here.

## Recipe: Open redirect

Not yet written. `py/url-redirection` (CWE-601, security severity 6.1 — the least severe of the
three, phishing-only impact) is also in `python-code-scanning.qls`. Lower priority than SSRF to
write up precisely because it's the safest of the three if something ever went wrong.
