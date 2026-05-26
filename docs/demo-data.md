# Demo Data

Roastnode includes an optional demo data loader for local exploration and screenshots.

## Command

```bash
bin/rails roastnode:demo:load
```

The task is idempotent. Running it again updates nothing and does not duplicate sample brews.

## Demo Login

- Email: `demo@roastnode.local`
- Password: `roastnode-demo`
- Workspace: `Roastnode Demo Household`

## Seeded Records

The demo household includes:

- one owner user
- one household workspace
- two open beans
- one grinder and one espresso machine
- four preparation tools
- two espresso brews with preparation tool snapshots
- one equipment event covering grinder cleaning and machine backflush

Creating the demo brews uses the normal `Brew` model callbacks, so inventory adjustments and remaining bean inventory behave like real logged brews.

## Production Guard

The Rake task refuses to run in production unless `ROASTNODE_ALLOW_DEMO_DATA=1` is set. This prevents accidental creation of known demo credentials on a public instance.

Do not load demo data on a hosted/public instance unless you immediately remove or change the demo credentials.
