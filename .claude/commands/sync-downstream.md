---
description: Sync downstream OpenShift repository with upstream kubernetes-sigs changes
---

Automate the process of syncing the downstream OpenShift kubernetes-sigs-lws repository with the upstream kubernetes-sigs/lws repository.

This command performs the following workflow:
1. Checkout downstream/main as the base
2. Fetch latest changes from both upstream and downstream remotes
3. Create a new sync-downstream branch from upstream/main
4. Merge downstream/main using -s ours strategy to preserve upstream changes
5. Carry over OpenShift-specific files from downstream/main
6. Create two commits:
   - "upstream<carry>: Downstream" - for carried files
   - "upstream<drop>: go mod tidy/vendor" - for go mod operations
7. Leave the branch ready for manual review and push to origin

## Files to carry from downstream

The following OpenShift-specific files/directories should be carried over from downstream/main:
- `.ci-operator.yaml` - OpenShift CI operator configuration
- `.snyk` - Snyk security scanning configuration
- `.tekton/` - Tekton pipeline definitions (entire directory)
- `Dockerfile.ocp` - OpenShift-specific Dockerfile
- `Dockerfile.ci` - CI-specific Dockerfile
- `Makefile-ocp.mk` - OpenShift-specific Makefile
- `renovate.json` - Renovate configuration
- `.gitignore` - OpenShift-specific ignore patterns
- `OWNERS` - OpenShift-specific ownership

## Execution Steps

**Important**: Before running this command, ensure:
1. You have git remotes configured:
   - `upstream` pointing to kubernetes-sigs/lws
   - `downstream` pointing to openshift/kubernetes-sigs-lws
   - `origin` pointing to your fork of openshift/kubernetes-sigs-lws
2. You have no uncommitted changes in your working directory
3. You're ready to perform the sync operation

Now perform the downstream sync workflow step by step:

1. First, verify the git remotes are configured correctly by running `git remote -v`
2. Checkout downstream/main: `git checkout downstream/main`
3. Fetch from both remotes: `git fetch downstream` and `git fetch upstream`
4. Create the sync-downstream branch from upstream/main: `git checkout -b sync-downstream upstream/main`
5. Merge downstream/main with -s ours strategy: `git merge -s ours downstream/main` (keeping upstream code but recording downstream history)
6. For each OpenShift-specific file/directory, checkout from downstream/main:
   - Try `git checkout downstream/main -- .ci-operator.yaml` (if error, skip and note)
   - Try `git checkout downstream/main -- .snyk` (if error, skip and note)
   - Try `git checkout downstream/main -- .tekton/` (if error, skip and note)
   - Try `git checkout downstream/main -- Dockerfile.ocp` (if error, skip and note)
   - Try `git checkout downstream/main -- Dockerfile.ci` (if error, skip and note)
   - Try `git checkout downstream/main -- Makefile-ocp.mk` (if error, skip and note)
   - Try `git checkout downstream/main -- renovate.json` (if error, skip and note)
   - Try `git checkout downstream/main -- .gitignore` (if error, skip and note)
   - Try `git checkout downstream/main -- OWNERS` (if error, skip and note)
   - Keep track of which files were successfully carried and which were skipped
7. Stage all carried files: `git add -A`
8. Create commit with message: `git commit -m "upstream<carry>: Downstream"`
9. Run `go mod tidy`
10. Run `go mod vendor`
11. Stage the go.mod, go.sum, and vendor/ changes: `git add go.mod go.sum vendor/`
12. Create commit with message: `git commit -m "upstream<drop>: go mod tidy/vendor"`
13. Display the branch status and summary of what was done

After completion, remind the user to:
- Review the changes with: `git log --oneline -10` and `git diff downstream/main`
- Check the carried files look correct
- If satisfied, push to your fork with: `git push --set-upstream origin sync-downstream`
- Create a pull request targeting downstream/main in the openshift/kubernetes-sigs-lws repository

Handle errors gracefully:
- If remotes don't exist, provide clear instructions on how to add them
- If there are uncommitted changes, warn the user and stop
- If merge conflicts occur during the -s ours merge, explain and provide guidance
- If a file doesn't exist in downstream/main during checkout, catch the error, skip it, and note which files were skipped
- If go mod commands fail, show the error and stop
- Display a summary at the end showing which files were carried and which were skipped