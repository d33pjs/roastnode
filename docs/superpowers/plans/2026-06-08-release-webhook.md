# Release Webhook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notify a private downstream Gitea workflow webhook with the new digest-pinned Roastnode image after GitHub creates a release container image.

**Architecture:** Extend the existing GitHub `Release Container` workflow with one optional shell step after release assets are attached. The step receives the webhook URL, token, and target ref as step-local GitHub secrets, skips safely when any are missing, builds JSON with `jq`, and posts the tag-plus-digest image reference with `curl -fsS`. Update release documentation so maintainers know which secrets enable the private webhook.

**Tech Stack:** GitHub Actions YAML, Bash, `jq`, `curl`, GHCR image references, Ruby YAML checks.

---

### File Structure

- Modify: `.github/workflows/release-container.yml`
  - Add one `Notify private deploy webhook` step immediately after `Attach SBOM and digest to GitHub Release`.
  - Keep webhook secrets scoped to that step's `env`.
  - Skip inside the shell script if `GITEA_DEPLOY_WEBHOOK_URL`, `GITEA_TOKEN`, or `GITEA_DEPLOY_REF` is blank.
- Modify: `docs/releasing.md`
  - Document the optional private deploy webhook secrets and the payload image format.

### Task 1: Add The Release Webhook

**Files:**
- Modify: `.github/workflows/release-container.yml`
- Modify: `docs/releasing.md`

- [x] **Step 1: Run the failing workflow-structure check**

Run:

```bash
ruby -ryaml -e 'workflow = YAML.load_file(".github/workflows/release-container.yml"); steps = workflow.fetch("jobs").fetch("publish").fetch("steps"); webhook = steps.find { |step| step["name"] == "Notify private deploy webhook" }; abort("missing deploy webhook step") unless webhook; env = webhook.fetch("env"); %w[GITEA_DEPLOY_WEBHOOK_URL GITEA_TOKEN GITEA_DEPLOY_REF IMAGE_REF IMAGE_DIGEST].each { |key| abort("missing env #{key}") unless env.key?(key) }; run = webhook.fetch("run"); abort("missing safe skip") unless run.include?("Skipping private deploy webhook") && run.include?("-z"); abort("missing jq payload") unless run.include?("jq -n") && run.include?("roastnode_image"); abort("missing configurable ref") unless run.include?("--arg ref") && run.include?("GITEA_DEPLOY_REF"); abort("missing tag plus digest image") unless run.include?("IMAGE_REF") && run.include?("RELEASE_TAG") && run.include?("IMAGE_DIGEST"); abort("missing auth header") unless run.include?("Authorization: token ${GITEA_TOKEN}"); abort("missing curl post") unless run.include?("curl -fsS -X POST")'
```

Expected: FAIL with `missing deploy webhook step`.

- [x] **Step 2: Insert the webhook step**

In `.github/workflows/release-container.yml`, insert this step immediately after the existing `Attach SBOM and digest to GitHub Release` step and before the first exodos.io upload step:

```yaml
      - name: Notify private deploy webhook
        env:
          GITEA_DEPLOY_WEBHOOK_URL: ${{ secrets.GITEA_DEPLOY_WEBHOOK_URL }}
          GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
          GITEA_DEPLOY_REF: ${{ secrets.GITEA_DEPLOY_REF }}
          IMAGE_REF: ${{ steps.image.outputs.ref }}
          IMAGE_DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          set -euo pipefail

          if [[ -z "$GITEA_DEPLOY_WEBHOOK_URL" || -z "$GITEA_TOKEN" || -z "$GITEA_DEPLOY_REF" ]]; then
            echo "Skipping private deploy webhook because GITEA_DEPLOY_WEBHOOK_URL, GITEA_TOKEN, or GITEA_DEPLOY_REF is not configured."
            exit 0
          fi

          image="${IMAGE_REF}:${RELEASE_TAG}@${IMAGE_DIGEST}"
          payload="$(jq -n \
            --arg ref "$GITEA_DEPLOY_REF" \
            --arg image "$image" \
            '{ref: $ref, inputs: {roastnode_image: $image}}')"

          curl -fsS -X POST \
            -H "Authorization: token ${GITEA_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$GITEA_DEPLOY_WEBHOOK_URL"
```

- [x] **Step 3: Update release documentation**

In `docs/releasing.md`, add this text under `## Required GitHub Settings`, after the existing exodos.io configuration list:

```markdown
Optional private deploy webhook:

- Secret `GITEA_DEPLOY_WEBHOOK_URL`: private downstream workflow webhook URL.
- Secret `GITEA_TOKEN`: token sent as `Authorization: token ${GITEA_TOKEN}`.
- Secret `GITEA_DEPLOY_REF`: downstream ref to dispatch, for example `master`.

When all three secrets are configured, the release workflow posts the digest-pinned image as `inputs.roastnode_image` after the GHCR image and GitHub Release assets exist. The image value includes both tag and digest, for example `ghcr.io/d33pjs/roastnode:v1.2.3@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`. If any secret is missing, release publishing continues and the webhook step logs only a safe skip message.
```

- [x] **Step 4: Run the workflow-structure check again**

Run the same Ruby command from Step 1.

Expected: PASS with exit code `0`.

- [x] **Step 5: Run the documentation check**

Run:

```bash
ruby -e 'text = File.read("docs/releasing.md"); %w[GITEA_DEPLOY_WEBHOOK_URL GITEA_TOKEN GITEA_DEPLOY_REF roastnode_image].each { |needle| abort("missing #{needle}") unless text.include?(needle) }'
```

Expected: PASS with exit code `0`.

- [x] **Step 6: Parse the workflow YAML**

Run:

```bash
ruby -ryaml -e 'YAML.load_file(".github/workflows/release-container.yml"); puts "workflow yaml ok"'
```

Expected: prints `workflow yaml ok`.

- [x] **Step 7: Inspect the implementation diff**

Run:

```bash
git diff -- .github/workflows/release-container.yml docs/releasing.md
```

Expected: the diff only adds the private deploy webhook step and release documentation. It should not change image build, signing, attestation, release upload, or exodos.io behavior.

- [x] **Step 8: Commit the implementation**

Run:

```bash
git add .github/workflows/release-container.yml docs/releasing.md docs/superpowers/plans/2026-06-08-release-webhook.md
git commit -m "Notify deploy webhook after release image build"
```
