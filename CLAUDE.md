# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repository is

**release-pipelines** holds the release machinery our repositories share: the
version computation, as a composite action, and the `cliff.toml` and
`commit-msg` templates that have to be real files in each consuming
repository. See README.md for the catalogue and the adoption steps.

It is a collaborative project — write documentation and commit messages in the
first person plural.

## The thing to hold in mind

**Every automated release in the organisation runs this code.** A fault here
is a fault in thirteen repositories at once, and it surfaces at the worst
moment: on a merge to `main`, when someone is expecting a release.

That is the trade made by extracting it, and the tests are what makes the
trade worth taking. `tests/test_next_version.py` builds *real* git
repositories with *real* merge topologies rather than asserting against
strings, because the failure this code exists to prevent was topological and
would pass every test written against a linear history.

Do not weaken that suite to make a change easier. If a change cannot be made
without breaking those tests, the change is probably wrong.

## Language

British English throughout — "behaviour", "organise", "licence" (noun),
"analyse". Sentence case for headings, never title case.

## Layout

```text
release-pipelines/
├── actions/next-version/
│   ├── action.yml          the composite action's interface
│   └── next_version.py     the implementation — standard library only
├── templates/
│   ├── cliff.toml          canonical changelog config
│   └── commit-msg          canonical Conventional Commits hook
├── tests/test_next_version.py
├── sync.sh                 copies the templates out, or checks them
└── .github/workflows/ci.yml
```

`next_version.py` lives **inside the action directory** so `action.yml` can
reach it as `${{ github.action_path }}/next_version.py` with no `../..`. The
test locates it by path, so moving it means editing one line there.

## Constraints that are load-bearing

**Standard library only, in `next_version.py`.** The action deliberately has
no `setup-python` and no install step, so it stays one cheap step in every
consuming workflow. An import of anything third-party breaks that.

**`sync.sh` must run on bash 3.2**, which is what macOS ships. No `mapfile`,
no associative arrays, no `${var,,}`.

**`sync.sh` writes only into repositories that were named.** With no targets
it checks every sibling that already carries a template and refuses to write.
A script that decides for itself which repositories to modify is not one
anybody should run.

**Absent is not drift.** Not every repository uses every template; `--check`
skips what is missing and fails only on a file that exists and differs.

## Changing the version policy

The policy is in `classify()` and `apply_bump()`, and is documented in
README.md's table. Changing it changes what every consuming repository
releases, so:

- Add tests first, in the topology that motivated the change.
- Say so in the commit message in terms of what a consumer will observe, not
  in terms of the diff.
- Tag a new major (`v2`) if a consumer's next release would come out
  differently. Consumers pin to a major tag, so a behaviour change under `v1`
  reaches them without their asking.

## Releasing this repository

Tags are what consumers pin to, so the tag *is* the interface.

- `v1`, `v2` — the moving major tags consumers reference. Repoint after a
  release.
- `v1.2.3` — the immutable tag each release also carries.

A change to `action.yml`'s inputs or outputs is breaking. A change to the
version *policy* is breaking. A fix to the computation that makes a previously
wrong answer right is not, even though the answer changes — that is the
correction consumers are pinned here to receive.

## Commits

Conventional Commits, enforced by the hook in `templates/commit-msg` (this
repository is its own first consumer — install it with
`git config core.hooksPath .githooks` after `./sync.sh .`).

Format: `<type>[(scope)][!]: <description>`. Types: `feat`, `fix`, `docs`,
`style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Use the shared artefact as the scope where a change is specific to one:

```text
feat(next-version): treat a revert as a patch
fix(sync): handle a target with no .githooks directory
docs: record why bumped-version was rejected
```

## Guardrails

- Never edit a consuming repository's copy of a template directly — edit
  `templates/` here and sync, or the drift check will simply report your edit
  as drift.
- Never reference this repository from a consumer by `@main`. Pin to a tag.
- Every script needs a header comment block explaining its purpose,
  prerequisites, and how to run it.
