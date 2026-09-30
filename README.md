# wax_baseball_tableau_next — Keeping Score on Tableau Next, headless

The W6a sprint's Salesforce DX project: everything Tableau Next / Agentforce / hosted-MCP that
lives as **org metadata** for the `keeping-score-w6a` scratch org (expires 2026-10-03 — this repo is
the durable copy). The Data 360 layer beneath it (connections → streams → DMO → the `Keeping_Score`
SDM) is a sibling repo, `wax_baseball_datacloud_deploy`, whose `W6A-TABLEAU-NEXT-LOG.md` is the
sprint's working record. The parity harness and observability captures that *read* this org are in
`wax_baseball_parity`.

## What's here

| Path | What | Why it matters |
|---|---|---|
| `force-app/main/default/settings/` | Retrieved org `Settings` (EinsteinGpt · **EinsteinCopilot** · Bot · Analytics · EinsteinAI · AgentforceForDevelopers · CustomerDataPlatform · Ai4m) | `EinsteinCopilot.enableEinsteinGptCopilot=true` is the one deploy that **enabled Agentforce headlessly** and surfaced `Bot` / `GenAiPlannerBundle` / `GenAiPlugin` / `GenAiFunction`. `Bot.enableBots` refuses headless (legal-terms click) and wasn't needed. |
| `force-app/main/default/externalClientApps/` + `extlClntAppOauthSettings/` + `extlClntAppGlobalOauthSets/` | The **External Client App `Wax_TN_MCP`** — OAuth client for the Salesforce Hosted MCP servers | Created by metadata deploy in a scratch org (the docs' "can't create in scratch orgs" is Setup-UI-only). Scopes `MCP, RefreshToken`; PKCE; secret optional; **named-user JWT on**; callback `http://localhost:38000/callback`. The `consumerKey` in the global-settings file is a public PKCE client id, not a secret. |
| `semantics/keeping-score-business-preferences.md` | Source text of the `Keeping_Score` model's **business preferences** | Fixes Tableau Agent's "who is *I*" — without it Concierge filters on the running user's Id and returns confident zeros. Written via the Beta MCP; re-apply from this file. |

## The hosted-MCP wiring (client side, once per machine)

```
claude mcp add --transport http --scope user --client-id <consumerKey> --callback-port 38000 \
  tableau-next https://api.salesforce.com/platform/mcp/v1/sandbox/analytics/tableau-next
claude mcp login tableau-next        # browser, scratch user, test.salesforce.com
```

Same shape for `tableau-next-pilot` (`analytics/tableau-next-pilot`, the 155-tool Beta server),
`sobject-reads` (`platform/sobject-reads`), `data-cloud-queries` (`data/data-cloud-queries`),
`salesforce-api-context`, `metadata-experts`, `headless-360` (all `platform/…`). Org side: Setup →
API Catalog → MCP Servers (toggle each) and Setup → Tableau Next Features → Tableau Agent — the two
genuine GUI floors found in this sprint.

Servers added mid-session aren't visible to that session — drive them with
`claude -p --allowedTools "mcp__<server>__*" "<prompt>"`.

## Replay into a fresh scratch org

```
sf project deploy start -o <org> -m Settings:EinsteinCopilot
sf project deploy start -o <org> -m ExternalClientApplication:Wax_TN_MCP -m ExtlClntAppOauthSettings:Wax_TN_MCP -m ExtlClntAppGlobalOauthSettings:Wax_TN_MCP
sf project retrieve start -o <org> -m ExtlClntAppGlobalOauthSettings:Wax_TN_MCP   # picks up the new consumerKey
```

Deploys are all-or-nothing — a mixed batch rolls back the good component; deploy singly when probing.

The ECA files are published without their org-minted values: no `consumerKey` (the org mints one on deploy; the retrieve above brings it back) and no `oauthLink`. `contactEmail` is `owner@example.com`; set your own before deploying. That shape validated against the W6a org (`--dry-run`, 2026-09-30, as an update to the existing ECA).

## Piece 3 -- the YouTube highlights action (2026-09-06 -> 09-10)

`Highlight_Scout` (`aiAuthoringBundles/Highlight_Scout`) is an Agent Script agent with one action:
`GameHighlightsSearch`, an invocable Apex wrapper over the `YouTubeHighlights` External Service and the
`YouTube_Data_API` named credential (key on the external credential principal, set by
`scripts/set_youtube_credential.py`, never in source). It could not publish here: this scratch org was
minted without `Einstein1AIPlatform`, so it has no Agentforce license, and the CLI's fallback to
`test.api.salesforce.com` (forcedotcom/cli#3634) turns that into a fake network failure. It lives in
devorg instead, published headless with `sf agent publish authoring-bundle`, v3 active.

Two things v3 encodes, both ruled after measured failures: the date filter is in Apex (structured
date/home/away inputs, YouTube `publishedAfter/Before` bracketing the game day, lenient date parser),
and the search is a procedural `run` in the reasoning block gated on the three variables -- the model
never decides whether to search, and the answer is rendered from `videos_text`. A grounding
instruction is not a gate. `tests/` holds the Testing Center spec (legacy runner answers "none" on this
agent -- variables appear not to persist across its reasoning iterations; live preview is clean) and
the NGT spec (that runner is unusable on devorg: MasterLabel required, schema rejects it).
