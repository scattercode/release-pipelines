# Rollout

## Where it got to (1 September 2026)

| Step | State |
|---|---|
| This repository pushed, public, `v1` + `v1.0.0` tagged | **done** |
| CI green here, including the job that runs the action | **done** |
| `tetrak-easyocr-armenian` | **done** — verified end to end: the action computed `bump: none`, the release job correctly did nothing, no tag was cut, and the drift check passed |
| `tetrak` | **PR #64 open**, per its workflow — `main` takes nothing by direct push |
| `tetrak-hy-trainer` | **held deliberately — see below** |

**`tetrak-hy-trainer` is not pushed.** Seven commits sit on its local `main`,
and the `feat:` among them (`per-work held-out registry, and a charset diff
for new sources`) would cut **0.4.0** and publish it to PyPI, where a version
number can never be reused. That `feat` belongs to the harvest work, not to
the review, so the release is that work's call to make. Push when the harvest
is at a point where 0.4.0 is the right thing to cut.

Nothing else is outstanding.

---

**The rest of this file is the original plan, kept for the one repository that
has not been done yet.** The order still matters for it.

## Why the order matters

`tetrak`, `tetrak-hy-trainer` and `tetrak-easyocr-armenian` now reference
`scattercode/release-pipelines/actions/next-version@v1`, and their CI checks
out this repository at `ref: v1`.

Neither the repository nor the tag exists on GitHub yet. Push a consumer
first and its next merge to `main` fails at "Compute next version" with
*action not found* — no release is cut, nothing is corrupted, but the release
does not happen and the failure is at the least convenient moment.

## The order

### 1. Create and push this repository

```bash
cd release-pipelines
gh repo create scattercode/release-pipelines --public \
  --description "Shared release machinery: version computation, changelog config, commit hook" \
  --source . --remote origin --push
```

It must be **public**. `tetrak` is private, and a private repository can use a
public action; the reverse needs a token.

### 2. Tag it

Consumers pin to the moving major tag.

```bash
git tag -a v1.0.0 -m "v1.0.0"
git tag -a v1 -m "v1"
git push origin v1.0.0 v1
```

`v1` is repointed at each release; `v1.0.0` never moves.

### 3. Confirm CI is green here

The `action` job runs the action against this repository's own checkout, so a
green run is direct evidence that the thing the consumers are about to
reference resolves and produces its three outputs.

### 4. Then the consumers, one at a time

Push one, watch its next `main` build, and only then push the next. The
`templates` job in each repository's CI exercises the `ref: v1` checkout, so
it fails loudly if step 2 was missed.

```bash
cd ../tetrak-hy-trainer && git push          # lowest-stakes releases first
cd ../tetrak-easyocr-armenian && git push    # publishes to PyPI
cd ../tetrak && git push origin fix/review-findings   # opens a PR, per its workflow
```

`tetrak` takes nothing by direct push to `main`; the branch there is
`fix/review-findings` and goes through a pull request as usual.

## What is deliberately unaffected

**PyPI Trusted Publishing.** The `publish` jobs stay in each repository's own
`release.yml`. Trusted Publishers are configured against a workflow filename,
so moving publishing into a shared reusable workflow would change the OIDC
claim and break publishing until each project's PyPI settings were updated.
Sharing stops at the version computation for that reason — the shared part is
the logic, not the workflow.

**scatterskills.** Not migrated: its documented policy makes a `docs:` commit
a patch release and the shared action treats that as no release. See the
README's "Who uses what" for the reasoning.

## Rolling back

Each consumer's adoption is one commit touching `.github/workflows/`. Revert
it and the repository is self-contained again, except that
`tools/next_version.py` and its test were deleted in the same commit and come
back with the revert.

## After the rollout

Delete this file. It describes a migration, and a migration document that
outlives its migration becomes something someone follows by mistake.
