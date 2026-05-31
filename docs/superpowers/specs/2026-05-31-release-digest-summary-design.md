# Release Digest Summary Design

## Context

The release container workflow already writes a durable digest asset named `roastnode-image-<tag>.txt` and attaches it to the GitHub Release. That asset is the right machine-readable record, but it is hard to discover from a completed workflow run, especially on mobile.

## Decision

Add a human-readable GitHub Actions job summary to `.github/workflows/release-container.yml` after the image digest asset is written. The summary should show:

- the digest-pinned image reference, for example `ghcr.io/owner/roastnode@sha256:...`
- the raw image digest
- the release tag
- the source commit SHA
- the digest asset filename attached to the GitHub Release

Keep the existing release asset unchanged. Do not edit the generated GitHub Release body in this slice.

## User Experience

After the `Release Container` workflow finishes, maintainers can open the workflow run and read the image reference directly from the run summary without digging through logs or release assets. The summary should use copy-friendly fenced code blocks for the full image reference and digest.

## Implementation Notes

- Use `$GITHUB_STEP_SUMMARY` from a shell step.
- Reuse the workflow's existing `IMAGE_REF`, `IMAGE_DIGEST`, `SOURCE_SHA`, `RELEASE_TAG`, and `IMAGE_DIGEST_FILE` values.
- Place the summary step before release asset upload so the summary is available even if a later external upload step is skipped or fails.

## Testing

- Parse `.github/workflows/release-container.yml` as YAML.
- Inspect the diff to confirm the summary step only adds human-readable output and does not change image build, signing, attestation, release upload, or exodos.io behavior.
