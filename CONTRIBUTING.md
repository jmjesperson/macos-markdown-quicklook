# Contributing

MarkdownQuicklook uses GitHub flow: `main` is always releasable, and every change reaches it through a pull request from a short-lived branch. Building and testing are covered in the [README](README.md#contributor-prerequisites).

## How `main` is protected

Two rulesets apply to `main` (**Settings › Rules › Rulesets**):

| Ruleset | Rules | Who can bypass |
|---|---|---|
| main: checks and history | Pull request required; the "Test and build" check must pass on the latest commit; no force pushes; `main` can't be deleted | Nobody |
| main: code owner approval | One approving review from a code owner (`.github/CODEOWNERS`) | Repository admins, when merging a pull request |

GitHub doesn't let a pull request's author approve it, so the maintainer merges their own pull requests with the admin bypass. The bypass skips only the approval; the checks still apply.

## Maintainer workflow (@jmjesperson)

1. Branch from an up-to-date `main`:

   ```sh
   git switch main && git pull --ff-only
   git switch -c <type>/<short-name>      # for example fix/front-matter-tabs
   ```

2. Commit with [Conventional Commits](https://www.conventionalcommits.org/) prefixes (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`). Add user-visible changes to the `[Unreleased]` section of `CHANGELOG.md`.
3. Push and open a pull request:

   ```sh
   git push -u origin HEAD
   gh pr create --fill
   ```

4. Wait for "Test and build" to pass (about 2–3 minutes). A newer push to the same branch cancels the run in progress.

   ```sh
   gh pr checks --watch
   ```

5. Merge with the admin bypass, only once the check is green:

   ```sh
   gh pr merge --admin --squash --delete-branch
   git switch main && git pull --ff-only
   ```

### Releasing

1. On a branch, set `version` in `scripts/xcodeproj-config.json` and regenerate the project:

   ```sh
   scripts/generate-xcodeproj.py MarkdownQuicklook.xcodeproj "$(cat scripts/xcodeproj-config.json)"
   ```

2. Move the `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`, and update the comparison links at the bottom.
3. Open a pull request and merge it as above.
4. Tag the merge commit and push the tag:

   ```sh
   git switch main && git pull --ff-only
   git tag -a vX.Y.Z -m "MarkdownQuicklook X.Y.Z"
   git push origin vX.Y.Z
   ```

To rehearse a release first, run the workflow by hand: `gh workflow run release.yml --ref <branch>`, or **Actions › Release › Run workflow**. A manual run does everything except publish, and keeps the zip and notes as a downloadable artifact for 7 days.

The Release workflow reruns CI and checks that the tag matches the version. It then builds the zip and publishes the release with notes from `CHANGELOG.md`. A tag with a suffix, such as `v0.2.0-beta.1`, publishes a pre-release. Don't upload release zips by hand.

### When CI is broken by something outside the code

If "Test and build" fails because of the runner (for example, GitHub removes Xcode 26.6), nothing can merge. Fix `.github/workflows/ci.yml` in a pull request if you can. If the fix itself can't pass, pause the checks ruleset, merge, and turn it back on straight away:

```sh
gh api -X PUT repos/jmjesperson/macos-markdown-quicklook/rulesets/26651776 -f enforcement=disabled
# merge the fix
gh api -X PUT repos/jmjesperson/macos-markdown-quicklook/rulesets/26651776 -f enforcement=active
```

## Outside contributors

Thanks for helping. Please:

1. Fork the repository and branch from `main`.
2. Keep the change focused, and add or update tests in `Packages/MarkdownRenderer/Tests`. Run `swift test --package-path Packages/MarkdownRenderer` before opening the pull request.
3. If the change affects what renders, update `docs/markdown-support.md`. Note user-visible changes under `[Unreleased]` in `CHANGELOG.md`.
4. Open a pull request against `main`.

For a first-time contributor, GitHub waits for the maintainer to approve before running workflows on the pull request. Every pull request needs the code owner's approval and a passing "Test and build" check before it can merge.

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).
