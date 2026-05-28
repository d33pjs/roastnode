# Release Publishing Design

## Context

Roastnode is developed on a private Gitea origin and mirrored to GitHub. The public release authority should be GitHub because GitHub Releases, GitHub Container Registry, OIDC, Sigstore, and GitHub artifact attestations work together without long-lived signing keys. Gitea should keep doing local CI and mirroring work, but it should not attempt to publish GHCR images or call exodos.io.

## Decisions

- License Roastnode under `AGPL-3.0-only`, matching the network-service goal that modified public deployments give users access to the corresponding modified source.
- Keep GHCR as the only public container registry for v1. Docker Hub can be added later if discovery becomes important.
- Split workflows by host:
  - `.gitea/workflows/ci.yml` runs Gitea-safe CI only.
  - `.github/workflows/ci.yml`, `.github/workflows/source-sbom.yml`, and `.github/workflows/release-container.yml` are guarded for GitHub.
- Generate a source SBOM on every GitHub `main` push and upload it to exodos.io when the required secret and inventory variable are configured.
- Publish containers only from GitHub release events or an explicit manual dispatch for a release tag.
- Publish semver tags, a `latest` tag for non-prereleases, and a SHA tag, but document digest-pinned deployment as the secure path.
- Use keyless Sigstore/cosign signing and GitHub artifact attestations so no signing private key is stored in repository secrets.

## Release Flow

1. Develop and push normally to Gitea `main`.
2. Gitea push mirroring syncs commits and tags to GitHub.
3. GitHub CI runs on mirrored pushes and pull requests.
4. GitHub source SBOM workflow generates an SPDX JSON source SBOM, attests it against a source archive, and uploads it to exodos.io with `source` tags.
5. A maintainer creates a GitHub Release from a `vX.Y.Z` tag.
6. GitHub builds and pushes a multi-arch GHCR image, generates an SPDX container SBOM, signs the image digest with cosign, creates provenance and SBOM attestations, uploads SBOM/digest assets to the GitHub Release, and uploads the container SBOM to exodos.io.

## Required GitHub Configuration

- Secret `EXODOS_API_TOKEN`: exodos.io API token.
- Variable `EXODOS_INVENTORYROOT_ID`: exodos.io inventory root UUID.
- Optional variable `EXODOS_API_URL`: defaults to `https://api.exodos.io`.
- GitHub Actions permissions must allow packages write and OIDC token minting.
- If the repository is private, GitHub artifact attestations require a plan that supports private/internal attestations; public repositories can use the public-good Sigstore path.

## User Documentation

Self-hosters should deploy `ghcr.io/<owner>/roastnode@sha256:<digest>` rather than a mutable tag. Release docs should show how to verify cosign signatures and GitHub attestations before upgrading.
