#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const baseUrl = (process.env.POROROCA_API_URL ?? "http://127.0.0.1:4000").replace(/\/$/, "");
const apiToken = process.env.POROROCA_API_TOKEN;

async function request(path: string, init: RequestInit = {}): Promise<unknown> {
  if (!apiToken) throw new Error("POROROCA_API_TOKEN is required");
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      accept: "application/json",
      authorization: `Bearer ${apiToken}`,
      "content-type": "application/json",
      ...init.headers,
    },
  });
  const body = await response.json().catch(() => ({ error: `HTTP ${response.status}` }));
  if (!response.ok) throw new Error(`Pororoca API ${response.status}: ${JSON.stringify(body)}`);
  return body;
}

function result(value: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(value, null, 2) }],
    structuredContent: { result: value },
  };
}

const server = new McpServer(
  { name: "pororoca-ota", version: "0.1.0" },
  {
    instructions:
      "Pororoca OTA delivers signed native UI documents. Always inspect channel status before and after a mutation. Publish only an already-signed, locally verified bundle and default a new production rollout to 10% unless the user specifies otherwise. Treat publish, rollout, and rollback as explicit production mutations. Never request, expose, or place a private signing key or delivery token in a mobile app.",
  },
);

server.registerTool(
  "pororoca_channel_status",
  {
    title: "Get channel delivery status",
    description: "Inspect the live update, rollout percentage, adoption, compatibility, and health for one app channel.",
    inputSchema: { app: z.string().min(1), channel: z.string().min(1).default("production") },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ app, channel }) => result(await request(`/api/v1/apps/${encodeURIComponent(app)}/channels/${encodeURIComponent(channel)}`)),
);

server.registerTool(
  "pororoca_publish",
  {
    title: "Publish a signed update",
    description: "Publish an already-signed Pororoca bundle to an app channel and begin its staged rollout.",
    inputSchema: {
      app: z.string().min(1),
      channel: z.string().min(1).default("production"),
      external_id: z.string().min(1),
      label: z.string().min(1),
      platform: z.enum(["ios", "android"]),
      manifest: z.record(z.string(), z.unknown()),
      files: z.record(z.string(), z.string()),
      rollout_percentage: z.number().int().min(0).max(100).default(100),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  },
  async ({ app, channel, ...bundle }) =>
    result(await request(`/api/v1/apps/${encodeURIComponent(app)}/channels/${encodeURIComponent(channel)}/updates`, {
      method: "POST",
      body: JSON.stringify(bundle),
    })),
);

server.registerTool(
  "pororoca_set_rollout",
  {
    title: "Set rollout percentage",
    description: "Change what percentage of compatible installs receives the channel's current signed update.",
    inputSchema: {
      app: z.string().min(1),
      channel: z.string().min(1).default("production"),
      percentage: z.number().int().min(0).max(100),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async ({ app, channel, percentage }) =>
    result(await request(`/api/v1/apps/${encodeURIComponent(app)}/channels/${encodeURIComponent(channel)}`, {
      method: "PATCH",
      body: JSON.stringify({ rollout_percentage: percentage }),
    })),
);

server.registerTool(
  "pororoca_rollback",
  {
    title: "Roll back a channel",
    description: "Point a channel to its previous known-good update. Devices switch on their next update check.",
    inputSchema: { app: z.string().min(1), channel: z.string().min(1).default("production") },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false },
  },
  async ({ app, channel }) => result(await request(`/api/v1/apps/${encodeURIComponent(app)}/channels/${encodeURIComponent(channel)}/rollback`, { method: "POST" })),
);

await server.connect(new StdioServerTransport());
