# Releasing Roastnode

Roastnode is developed on the private Gitea origin and mirrored to GitHub. GitHub is the public release authority because GitHub Releases, GHCR, OIDC, Sigstore, and artifact attestations fit together without storing long-lived signing keys.

## Workflow Split

- Gitea runs `.gitea/workflows/ci.yml` for normal Rails checks and comparative source SBOM uploads.
- GitHub runs `.github/workflows/source-sbom.yml` and `.github/workflows/release-container.yml` for release supply-chain artifacts only.
- GitHub does not run duplicate Rails CI. The source SBOM and release workflows are separate from CI because they need GitHub Releases, GHCR, OIDC, Sigstore, and GitHub artifact attestations.
- GitHub workflows include a `github.server_url == 'https://github.com'` guard so a Gitea runner that notices `.github/workflows` does not try to publish images or upload SBOMs.
- Gitea push mirroring syncs commits, branches, and tags. The release workflow creates or updates GitHub Release objects on GitHub.

## Required GitHub Settings

Configure these in the mirrored GitHub repository:

- Secret `EXODOS_API_TOKEN`: exodos.io API token.
- Variable `EXODOS_INVENTORYROOT_ID`: exodos.io inventory root UUID for source SBOM uploads.
- Variable `EXODOS_INVENTORYROOT_SPDX_ID`: exodos.io inventory root UUID for SPDX uploads.
- Variable `EXODOS_INVENTORYROOT_CDX_ID`: exodos.io inventory root UUID for CycloneDX uploads.
- Optional variable `EXODOS_API_URL`: defaults to `https://api.exodos.io`.

Optional private deploy webhook:

- Secret `GITEA_DEPLOY_WEBHOOK_URL`: private downstream workflow webhook URL.
- Secret `GITEA_TOKEN`: token sent as `Authorization: token ${GITEA_TOKEN}`.
- Secret `GITEA_DEPLOY_REF`: downstream ref to dispatch, for example `master`.

When all three secrets are configured, the release workflow posts the digest-pinned image as `inputs.roastnode_image` after the GHCR image and GitHub Release assets exist. The image value includes both tag and digest, for example `ghcr.io/d33pjs/roastnode:v1.2.3@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`. If any secret is missing, release publishing continues and the webhook step logs only a safe skip message.

GHCR publishing uses the built-in `GITHUB_TOKEN`. Keyless cosign signing and GitHub artifact attestations use GitHub OIDC, so no cosign private key is required.

The Gitea push mirror token for GitHub needs permission to update workflow files. For a classic GitHub token this means including the `workflow` scope in addition to repository write access.

If GitHub is still private, artifact attestations may require a GitHub plan that supports private/internal attestations. Public repositories can use the public Sigstore path.

## Required Gitea Settings

Configure these in the private Gitea repository when CI should upload source SBOMs to exodos.io:

- Secret `EXODOS_API_TOKEN`: exodos.io API token.
- Optional variable `EXODOS_API_URL`: defaults to `https://api.exodos.io`.
- Variable `EXODOS_INVENTORYROOT_SYFT_SPDX_ID`: inventory root UUID for Syft SPDX source SBOM uploads.
- Variable `EXODOS_INVENTORYROOT_SYFT_CDX_ID`: inventory root UUID for Syft CycloneDX source SBOM uploads.
- Variable `EXODOS_INVENTORYROOT_CDX_CDX_ID`: inventory root UUID for cdxgen CycloneDX source SBOM uploads.
- Variable `EXODOS_INVENTORYROOT_MIKEBOM_SPDX_ID`: inventory root UUID for mikebom SPDX 3.0.1 source SBOM uploads.
- Variable `EXODOS_INVENTORYROOT_MIKEBOM_CDX_ID`: inventory root UUID for mikebom CycloneDX 1.6 source SBOM uploads.

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

1. Make sure `main` is green on Gitea.
2. Choose a semver tag such as `v0.1.0`.
   - Roastnode uses `vX.Y.Z`, with `X` up to 2 digits, `Y` up to 3 digits, and `Z` up to 4 digits.
   - Unless the release is explicitly called a minor release, increment `Z` by 1 from the latest release tag.
   - Example: `v0.9.9` is followed by `v0.9.10`.
3. Tag the exact commit you want to release:

   ```bash
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

4. Confirm Gitea mirrored the tag to GitHub.
5. Confirm the GitHub `Release Container` workflow starts automatically from the mirrored tag.
6. The automatic tag run publishes the GitHub Release after attaching generated assets. This is required when GitHub release immutability is enabled, because published immutable releases cannot accept new or replacement assets.
7. The GitHub `Release Container` workflow will:
   - Build `linux/amd64` and `linux/arm64` images.
   - Bake the release tag into the image as the default `ROASTNODE_VERSION`.
   - Push the image to GHCR.
   - Apply `vX.Y.Z`, `X.Y.Z`, `X.Y`, `latest` for stable releases, and `sha-<short-commit>` tags.
   - Generate SPDX and CycloneDX container SBOMs.
   - Attach the SBOM and an image digest file to the GitHub Release.
   - Sign the image digest with keyless cosign.
   - Create GitHub provenance and SBOM attestations.
   - Upload the container SBOMs to exodos.io with tags `roastnode`, `container`, the release tag, the commit SHA, and unique `latest-container`.

If you need to rebuild or inspect a release before publication, run the workflow manually with `release_tag` set to the existing tag. Leave `publish_release` enabled for the normal path, or disable it to keep the GitHub Release as a draft while you inspect the attached assets. Do not publish the release before the assets are attached when release immutability is enabled.

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
