# Profile, Workspace Media, and Navigation Polish Plan

**Goal:** Let users and households attach identity media, surface those images on brew cards, and make detail navigation feel linked and mobile-friendly.

**Architecture:** Use Rails Active Storage one-to-one attachments for user and workspace identity images. Keep delivery behind `MediaAttachmentsController`, extending its authorization from workspace-owned domain records to workspace memberships and the current active workspace. Reuse a shared back-link partial and existing Tailwind conventions.

## Chunks

- [x] Add model/controller tests for user avatar/banner and workspace logo/banner uploads.
- [x] Add media controller tests for user and workspace attachment visibility.
- [x] Add brew hero/detail tests for avatar, workspace logo, and domain links.
- [x] Add equipment event/preparation tool navigation tests.
- [x] Implement `User` and `Workspace` identity attachments and settings form previews.
- [x] Extend private media authorization for user and workspace records.
- [x] Add avatar/logo to the brew hero card and link beans, equipment, and preparation tools.
- [x] Replace old text-style back links with a shared button-like partial.
- [x] Update docs and the agent guide.
- [ ] Run focused tests, then full verification.
