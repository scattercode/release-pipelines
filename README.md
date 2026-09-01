# release-pipelines

The release machinery our repositories share: one implementation of "what is
the next version?", and the templates that would otherwise be copied into
every repository and quietly drift apart.

## Why this exists

Thirteen repositories carry an identical `cliff.toml` and an identical
`.githooks/commit-msg`. Three carried a byte-identical `next_version.py` and
its 200-line test suite. A fourth was still running `git cliff
--bumped-version`, the approach those three replaced after it silently skipped
a major release.

Nothing detected any of that. A fix applied in one repository stayed there,
and the copy that drifts is always the one nobody is looking at.

## What is shared, and how

Two mechanisms, chosen by what each artefact *is* rather than by preference.

| Artefact | Mechanism | Why |
|---|---|---|
| Version computation | **Composite action** | Runs only in CI, so it can live here and be referenced remotely. True deduplication — there is one copy. |
| `cliff.toml` | **Synced copy, checked** | git-cliff reads it from the consuming repository's root, so it has to be a real file there. |
| `.githooks/commit-msg` | **Synced copy, checked** | git runs hooks from the checkout, same constraint. |

### The next-version action

```yaml
- name: Check out full history
  uses: actions/checkout@v7
  with:
    fetch-depth: 0          # required: this reads tags and a commit range

- name: Compute next version
  id: version
  uses: scattercode/release-pipelines/actions/next-version@v1

- name: Release
  if: steps.version.outputs.release == 'true'
  run: echo "releasing ${{ steps.version.outputs.next }}"
```

| Output | Meaning |
|---|---|
| `next` | The next version, keeping the previous tag's `v` prefix. Empty when there is nothing to release. |
| `release` | `"true"` or `"false"` — branch on this. |
| `bump` | `major`, `minor`, `patch`, or empty. |

Standard library only, so it needs no `setup-python` and no install.

**`fetch-depth: 0` is not optional.** The action reads tags and the commit
range since the last one; a shallow clone has neither, and the result is a
wrong answer rather than an error.

### The templates

```bash
./sync.sh --check                      # verify every sibling that carries them
./sync.sh --check ../tetrak            # verify one
./sync.sh ../tetrak ../scatterskills   # write them in
```

`--check` is the part that earns its keep, and is worth a step in each
consuming repository's CI. Writing requires naming the targets: a sync script
should not decide by itself which repositories to modify.

## Why not `git cliff --bumped-version`

git-cliff answers "what is the next version?" by bucketing the *entire*
history into releases first, and that bucketing goes wrong on merge topology.

On 2026-08-22 a branch cut before 4.3.0 and merged after 4.4.1 had all six of
its commits — including a `feat!` with a `BREAKING CHANGE` footer — filed
under release 4.3.0, whose tag is not even an ancestor of them. With nothing
left unreleased, git-cliff reported "nothing to bump", and 5.0.0 was skipped
while the workflow went green.

The version only ever depended on one commit range. Reading that range
directly is deterministic, independent of topology, and testable — which is
what `tests/` does, by building real repositories with real merge topologies.

git-cliff still writes the changelog, where a mis-bucketed old release is a
cosmetic wart rather than a blocked release.

## The version policy

Computed from the Conventional Commit history since the last tag:

| Commits since the last tag | Bump |
|---|---|
| Any `!` marker or `BREAKING CHANGE:` footer | major |
| Any `feat` | minor |
| Any `fix`, `perf`, `revert` | patch |
| Only `docs`, `chore`, `style`, `test`, `ci`, `build`, `refactor` | none — no release |

Two things it will not do quietly:

- A releasable change that computes no version **fails the run**. That is the
  exact failure this replaced, so it is reported rather than passed over.
- A commit whose subject is not a Conventional Commit is ignored for
  versioning and **warned about**, because the commit-msg hook should have
  made it impossible — one appearing means the hook was bypassed, and a
  release-worthy change may be invisible.

## Who uses what

| Repository | next-version action | Templates checked |
|---|---|---|
| `tetrak` | yes | yes |
| `tetrak-hy-trainer` | yes | yes |
| `tetrak-easyocr-armenian` | yes | yes |
| `scatterskills` | **no — see below** | yes |
| the other nine | not applicable (no automated release) | available |

**scatterskills deliberately has not adopted the action**, and this is the one
place a policy genuinely differs rather than merely having been copied.

Its documented policy makes a documentation or tooling commit a **patch
release**, on the grounds that people install individual skills and any
change to the guidance is worth a version. The action treats `docs`, `chore`,
`style`, `test`, `ci`, `build` and `refactor` as **no release at all**.

Adopting the action there would therefore stop cutting releases it currently
cuts. That is a decision about that library's versioning, not a mechanical
migration, so it has been left alone — and written down here so the difference
is visible rather than discovered.

It does still run `git cliff --bumped-version`, which is what this action
replaced. If it adopts the action, it gains the topology fix; if it does not,
it keeps the exposure. Either is defensible; drifting into one by accident is
not.

## Adopting it in a repository

1. Add the `--check` step to CI and run `./sync.sh --check ../<repo>` locally.
2. Replace the "Compute next version" step with the action, pinned to a tag.
3. Delete the repository's `tools/next_version.py` and its test.

Pin to a tag (`@v1`), not to `main`: this repository is depended on by every
release, so an unpinned reference makes every repository's next release
contingent on an unrelated commit here.

## Licence

MIT.
