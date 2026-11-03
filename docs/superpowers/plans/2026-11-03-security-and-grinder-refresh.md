# Security and grinder guidance refresh

The user authorizes implementation, commits, pushes, release publication and deployment from Santiago without further approval. Work stays on `main`.

- [x] Preserve production state and available crash/request/process/file/network evidence locally before replacing containers. Check Ruby's primary advisory and application regex entry points. Record limitations; absence of indicators cannot establish absence of compromise.
- [x] Refresh stable compatible runtime, gem, browser, CI and supply-chain tool dependencies. Keep PostgreSQL on its current supported major. Verify published artifacts and run fresh dependency audits.
- [x] Reproduce grinder guidance failures with regression tests. Preserve physical chronology across closed bags and independent drafts. Require the panel's green state to agree with the latest physical grinder use. Show the last use's total time, beverage and ratio for every setting.
- [x] Review the combined changes, run the Rails and JavaScript suites, browser checks, lint, security scans and production assets; document actual results and compatibility constraints.
- [x] Commit and push; require passing Gitea CI; publish patch release `v0.9.34` with a public changelog. Check the mirrored tag, release assets, image revisions, signature and attestations.
- [x] Validate a fresh production backup. Update the Santiago infrastructure checkout to the verified immutable release image and run the Roastnode-only Ansible play. Verify health, exact runtime/image, migrations, queue and a fresh validated backup; restart the LAN development preview in `roastnode-dev` tmux.
