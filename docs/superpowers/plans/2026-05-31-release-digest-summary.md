# Release Digest Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the release container's digest-pinned image URL in the completed GitHub Actions workflow run summary.

**Architecture:** Keep the current release workflow behavior unchanged: build, sign, attest, create the digest asset, and attach it to the GitHub Release as before. Add one shell step that writes human-readable Markdown to `$GITHUB_STEP_SUMMARY` using values already produced by earlier workflow steps.

**Tech Stack:** GitHub Actions YAML, Bash, Docker Buildx outputs, GHCR image references.

---

### Task 1: Add The Workflow Summary Step

**Files:**
- Modify: `.github/workflows/release-container.yml`

- [x] **Step 1: Run the failing workflow-structure check**

Run:

```bash
ruby -ryaml -e 'workflow = YAML.load_file(".github/workflows/release-container.yml"); steps = workflow.fetch("jobs").fetch("publish").fetch("steps"); summary = steps.find { |step| step["name"] == "Add image digest to workflow summary" }; abort("missing workflow summary step") unless summary; run = summary.fetch("run"); abort("summary does not write to GITHUB_STEP_SUMMARY") unless run.include?("$GITHUB_STEP_SUMMARY"); abort("summary missing image reference") unless run.include?("IMAGE_REF") && run.include?("IMAGE_DIGEST"); abort("summary missing release metadata") unless run.include?("RELEASE_TAG") && run.include?("SOURCE_SHA") && run.include?("IMAGE_DIGEST_FILE")'
```

Expected: FAIL with `missing workflow summary step`.

- [x] **Step 2: Add the summary step after `Write image digest asset`**

Insert this step in `.github/workflows/release-container.yml` immediately after the existing `Write image digest asset` step and before `Attach SBOM and digest to GitHub Release`:

```yaml
      - name: Add image digest to workflow summary
        env:
          IMAGE_REF: ${{ steps.image.outputs.ref }}
          IMAGE_DIGEST: ${{ steps.build.outputs.digest }}
          SOURCE_SHA: ${{ steps.source.outputs.sha }}
        run: |
          set -euo pipefail

          {
            echo "## Container image"
            echo
            echo "Digest-pinned image:"
            echo
            echo '```'
            echo "${IMAGE_REF}@${IMAGE_DIGEST}"
            echo '```'
            echo
            echo "Digest:"
            echo
            echo '```'
            echo "${IMAGE_DIGEST}"
            echo '```'
            echo
            echo "- Release tag: \`${RELEASE_TAG}\`"
            echo "- Source commit: \`${SOURCE_SHA}\`"
            echo "- Release asset: \`${IMAGE_DIGEST_FILE}\`"
          } >> "$GITHUB_STEP_SUMMARY"
```

- [x] **Step 3: Run the workflow-structure check again**

Run the same Ruby command from Step 1.

Expected: PASS with exit code `0`.

- [x] **Step 4: Parse the workflow as YAML**

Run:

```bash
ruby -ryaml -e 'YAML.load_file(".github/workflows/release-container.yml"); puts "workflow yaml ok"'
```

Expected: prints `workflow yaml ok`.

- [x] **Step 5: Inspect the diff**

Run:

```bash
git diff -- .github/workflows/release-container.yml
```

Expected: the diff only adds the `Add image digest to workflow summary` step and does not change build, signing, attestation, release upload, or exodos.io behavior.

- [x] **Step 6: Commit**

Run:

```bash
git add .github/workflows/release-container.yml docs/superpowers/plans/2026-05-31-release-digest-summary.md
git commit -m "Show release image digest in workflow summary"
```
