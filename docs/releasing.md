# Releasing Roastnode

Roastnode is developed on the private Gitea origin and mirrored to GitHub. GitHub is the public release authority because GitHub Releases, GHCR, OIDC, Sigstore, and artifact attestations fit together without storing long-lived signing keys.

## Workflow Split

- Gitea runs `.gitea/workflows/ci.yml` for normal Rails checks only.
- GitHub runs `.github/workflows/ci.yml`, `.github/workflows/source-sbom.yml`, and `.github/workflows/release-container.yml`.
- GitHub workflows include a `github.server_url == 'https://github.com'` guard so a Gitea runner that notices `.github/workflows` does not try to publish images or upload SBOMs.
- Gitea push mirroring syncs commits, branches, and tags. Create GitHub Release objects on GitHub.

## Required GitHub Settings

Configure these in the mirrored GitHub repository:

- Secret `EXODOS_API_TOKEN`: exodos.io API token.
- Variable `EXODOS_INVENTORYROOT_ID`: exodos.io inventory root UUID.
- Optional variable `EXODOS_API_URL`: defaults to `https://api.exodos.io`.

GHCR publishing uses the built-in `GITHUB_TOKEN`. Keyless cosign signing and GitHub artifact attestations use GitHub OIDC, so no cosign private key is required.

The Gitea push mirror token for GitHub needs permission to update workflow files. For a classic GitHub token this means including the `workflow` scope in addition to repository write access.

If GitHub is still private, artifact attestations may require a GitHub plan that supports private/internal attestations. Public repositories can use the public Sigstore path.

## Source SBOMs

Every push to GitHub `main` runs the source SBOM workflow:

1. Build a source archive from the mirrored commit.
2. Generate `roastnode-source-<sha>.spdx.json`.
3. Create a GitHub SBOM attestation for the source archive.
4. Upload the SBOM to exodos.io with tags:
   - `roastnode`
   - `source`
   - `main`
   - `sha-<commit>`
   - unique `latest-source`

If exodos.io settings are missing, the workflow keeps the SBOM artifact but skips the external upload.

## Release Steps

1. Make sure `main` is green on Gitea and GitHub.
2. Choose a semver tag such as `v0.1.0`.
3. Tag the exact commit you want to release:

   ```bash
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

4. Confirm Gitea mirrored the tag to GitHub.
5. Create a GitHub Release from that tag.
6. The GitHub `Release Container` workflow will:
   - Build `linux/amd64` and `linux/arm64` images.
   - Push the image to GHCR.
   - Apply `vX.Y.Z`, `X.Y.Z`, `X.Y`, `latest` for stable releases, and `sha-<short-commit>` tags.
   - Generate an SPDX container SBOM.
   - Attach the SBOM and an image digest file to the GitHub Release.
   - Sign the image digest with keyless cosign.
   - Create GitHub provenance and SBOM attestations.
   - Upload the container SBOM to exodos.io with tags `roastnode`, `container`, the release tag, the commit SHA, and unique `latest-container`.

## Verifying a Release

Prefer the digest from the release asset `roastnode-image-vX.Y.Z.txt`.

```bash
IMAGE="ghcr.io/OWNER/roastnode@sha256:REPLACE_WITH_DIGEST"
REPO="OWNER/roastnode"
TAG="v0.1.0"

cosign verify \
  --certificate-identity "https://github.com/${REPO}/.github/workflows/release-container.yml@refs/tags/${TAG}" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${IMAGE}"

gh attestation verify "oci://${IMAGE}" -R "${REPO}"
```

For a manually dispatched rebuild, verify against the workflow identity shown by `cosign verify` or the GitHub attestation output before trusting it for production.

## License

Roastnode is licensed as `AGPL-3.0-only`. In practical terms for this project: if someone modifies Roastnode and runs that modified version for users over a network, the AGPL expects those users to have access to the corresponding modified source. This is a project policy note, not legal advice.
