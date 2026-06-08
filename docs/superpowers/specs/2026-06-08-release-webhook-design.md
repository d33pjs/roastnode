# Release Webhook Design

## Context

Roastnode's `Release Container` GitHub workflow already builds the multi-arch GHCR image, signs it, writes the digest asset, summarizes the digest-pinned image reference, and attaches release assets to the GitHub Release. Production deployment currently relies on a human copying the immutable image reference into `ROASTNODE_IMAGE`.

The release flow should optionally notify a private downstream Gitea automation endpoint after a release image has been created, using GitHub repository secrets for the endpoint, token, and target ref.

## Decision

Add an optional private webhook step to `.github/workflows/release-container.yml` after the release assets are attached or updated. The step sends a POST request only when all required webhook secrets are configured:

- `GITEA_DEPLOY_WEBHOOK_URL`: downstream webhook URL.
- `GITEA_TOKEN`: token sent as `Authorization: token ${GITEA_TOKEN}`.
- `GITEA_DEPLOY_REF`: downstream ref to dispatch, such as `master`.

The JSON body should be:

```json
{
  "ref": "master",
  "inputs": {
    "roastnode_image": "ghcr.io/d33pjs/roastnode:v1.2.3@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}
```

The image input must include both the release tag and digest as `IMAGE_REF:RELEASE_TAG@IMAGE_DIGEST`, matching the downstream deployment contract. For this repository, `steps.image.outputs.ref` resolves to `ghcr.io/d33pjs/roastnode` on GitHub.

## Security And Privacy

The webhook URL, token, and ref stay in GitHub secrets and are not committed. The workflow should avoid printing the token, URL, or full JSON payload. Missing secrets should produce a safe skip message rather than failing unrelated release publishing.

The step should use `curl -fsS` so HTTP or transport failures fail the workflow once the webhook is intentionally configured. JSON should be built with `jq` instead of shell string interpolation so configured refs and image references are escaped correctly.

## User Experience

For normal configured releases, maintainers tag and push as before. After GitHub publishes the image and release assets, the workflow notifies the private downstream automation with the immutable image reference. If the webhook secrets are not configured, release publishing still succeeds and the workflow summary/digest asset remain available for manual deployment.

## Testing

- Parse `.github/workflows/release-container.yml` as YAML.
- Run a workflow-structure check that confirms the webhook step exists, reads the three secret-backed environment variables, builds payload JSON with `jq`, sends the `Authorization: token` header, and includes `roastnode_image`.
- Inspect the diff to confirm the change is limited to release webhook behavior and release documentation.
