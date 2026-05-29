# Release Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AGPL licensing, keep Rails CI on Gitea, and publish GitHub release containers with SBOMs, attestations, signatures, exodos.io upload, and digest-pinned user documentation.

**Architecture:** Gitea owns normal CI through `.gitea/workflows/ci.yml`. GitHub owns source SBOM upload and release image publishing through guarded workflows under `.github/workflows`. Release artifacts are attached to GitHub Releases and uploaded to exodos.io when configured.

**Tech Stack:** Rails 8.1, GitHub Actions, Gitea Actions, GHCR, Docker Buildx, Anchore Syft SBOM action, GitHub artifact attestations, Sigstore cosign, exodos.io REST API.

---

### Task 1: License

**Files:**
- Modify: `LICENSE`
- Modify: `README.md`

- [x] Replace the temporary MIT license with the AGPL-3.0 license text.
- [x] Add README license metadata pointing at `LICENSE`.

### Task 2: Workflow Split

**Files:**
- Create: `.gitea/workflows/ci.yml`
- Remove: `.github/workflows/ci.yml`

- [x] Add a Gitea CI workflow that runs checks/tests only and never builds or publishes container images.
- [x] Remove duplicate GitHub CI; SBOM and attestation workflows remain separate GitHub-only release supply-chain jobs.

### Task 3: Source SBOM Upload

**Files:**
- Create: `.github/workflows/source-sbom.yml`

- [x] Generate an SPDX JSON SBOM for the source tree on `main` pushes.
- [x] Create a source archive and attach a GitHub SBOM attestation.
- [x] Upload the SBOM to exodos.io when `EXODOS_API_TOKEN` and `EXODOS_INVENTORYROOT_ID` are configured.

### Task 4: Release Container Publishing

**Files:**
- Create: `.github/workflows/release-container.yml`

- [x] Build and push a multi-arch image to GHCR on GitHub release publication.
- [x] Generate semver, latest, and SHA tags while documenting digest-pinned deployment.
- [x] Generate and attach container SBOM and build provenance attestations.
- [x] Sign the image digest with keyless cosign.
- [x] Upload release SBOM and digest artifacts to GitHub Releases and exodos.io.

### Task 5: Documentation and Verification

**Files:**
- Create: `docs/releasing.md`
- Modify: `docs/production-self-hosting.md`
- Modify: `README.md`

- [x] Document maintainer release steps, required GitHub secrets/variables, and Gitea/GitHub split.
- [x] Document self-hosted upgrades by image digest.
- [x] Parse YAML files and run whitespace verification.
