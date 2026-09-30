# Keeping_Score — business preferences (Source)

The doctrine text written to the `Keeping_Score` semantic model's `businessPreferences` via the
Tableau Next Beta MCP tool `update_semantic_model_business_preferences` (2026-09-05). This file
is the one home for the text; the MCP call is the generator — re-apply from here, never edit in
the org.

**Why it exists:** without it, Tableau Agent (Concierge) resolves *I / me / my* to the running
user's Salesforce Id and silently injects `Game_Attendee.attendee_key = <user id>` — confident
zeros ("You didn't witness any home runs… a unique insight!"). The model is one person's
attendance, so first person means the whole model. Measured before/after in
`wax_baseball_datacloud_deploy/W6A-TABLEAU-NEXT-LOG.md`.

## Text (verbatim)

```
Keeping Score is one person's baseball attendance record: George "Wax" Weatherwax's 178 attended MLB games, 1984-2025. When the user says I, me, my, mine, or we, they mean the ENTIRE model. Never filter by attendee, attendee_key, Game_Attendee, or the current Salesforce user unless the question names a specific attendee by name. Game_Attendee lists companions who came to games with Wax. Governed measures: Games_Attended, Unique_Stadiums, Home_Runs_Witnessed, Runs_Witnessed, Hall_of_Famers_Seen, Attended_Win_Rate (grouped by Attended_Team_Games.team_id; NYA = New York Yankees). Game_Year is the calculated year dimension.
```

## Re-apply

Headless, via a `claude -p` subprocess (the hosted-MCP OAuth token lives in Claude Code's store):

```
claude -p --allowedTools "mcp__tableau-next-pilot__*" \
  "Call update_semantic_model_business_preferences for Keeping_Score with the text in semantics/keeping-score-business-preferences.md, then get_semantic_model_business_preferences and print businessPreferences."
```

Verify: `analyze_data` on `Keeping_Score` — *"How many home runs have I witnessed?"* → 400, and
`troubleshootingInfo.query` carries no `flattenFilter` on `Game_Attendee`.
