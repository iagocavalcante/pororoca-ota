# Pororoca OTA MCP server

The MCP server lets a coding agent inspect delivery state, change rollout, publish a prepared signed bundle, and roll back a channel over the same authenticated API as the dashboard.

The complete Codex setup, safe operating loop, and troubleshooting guide is at [pororoca-ota.fly.dev/docs/mcp](https://pororoca-ota.fly.dev/docs/mcp).

## 1. Build it

```sh
npm ci
npm run build
POROROCA_API_URL=https://pororoca-ota.fly.dev \
POROROCA_API_TOKEN=pororoca_live_... \
node dist/index.js
```

Use Node 22 or newer. Create a `delivery` token in the dashboard and copy it when shown; it cannot be recovered later.

## 2. Add it to an MCP client

For Codex:

```sh
codex mcp add pororoca \
  --env POROROCA_API_URL=https://pororoca-ota.fly.dev \
  --env POROROCA_API_TOKEN=pororoca_live_... \
  -- node /absolute/path/to/pororoca-ota/mcp/dist/index.js
codex mcp list
```

For another MCP client, use the absolute path to this checkout's compiled entry point:

```json
{
  "mcpServers": {
    "pororoca": {
      "command": "node",
      "args": ["/absolute/path/to/pororoca-ota/mcp/dist/index.js"],
      "env": {
        "POROROCA_API_URL": "https://pororoca-ota.fly.dev",
        "POROROCA_API_TOKEN": "pororoca_live_..."
      }
    }
  }
}
```

Restart the MCP client, then ask it to run `pororoca_channel_status` for your app slug and `production` channel. That read-only check confirms the connection before any delivery mutation.

## 3. Use the delivery tools

- `pororoca_channel_status` — inspect the current update, rollout, adoption, compatibility, and health.
- `pororoca_publish` — publish an existing signed manifest plus base64-encoded bundle files.
- `pororoca_set_rollout` — idempotently set the current rollout percentage.
- `pororoca_rollback` — restore the previous known-good update for devices on their next check.

The shortest safe operating loop is: inspect status, publish at 10%, inspect adoption and errors, widen the rollout, and roll back if health regresses. The MCP server does not create or sign bundles; use the publisher CLI for that step.

Use a `delivery`-scoped token for MCP. Status reads require a valid token; publishing, rollout changes, and rollback additionally require an active Pororoca subscription. Generate and revoke tokens from the dashboard; the full token is displayed only once.

The server uses stdio, so stdout is reserved for MCP messages. Keep secrets in the MCP client's environment configuration, never in prompts or source control.
