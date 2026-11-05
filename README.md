# FISH MCP Code Sample

Code extracted from **FISH**, a school management and communication platform developed by Brandon McCandlish.

This repository is a focused code sample extracted from the larger FISH Rails application. It demonstrates the architecture of FISH's Model Context Protocol (MCP) integration and is **not runnable on its own**: it requires the full FISH application. Supporting models, application configuration, and unrelated product code have intentionally been omitted.


## What this demonstrates

The MCP layer gives an authenticated user's LLM access to narrowly scoped FISH tools while relying on the existing Rails application for authorization, business rules, and data access.

A deliberate design decision is that an LLM cannot directly commit certain changes to FISH. For example, `DraftCalendarImport` allows an LLM to identify and propose calendar events, but creates an expiring draft for human review rather than directly adding those events to a school or group calendar.

An admin or coach could use their LLM of choice to parse an email containing upcoming JV basketball games, create a proposed calendar import, and then review and commit those events inside FISH.

The tool registry in `server.rb` lists the full tool set; five representative tools are included here to show the range without duplicating the same patterns twelve times.

## Authorization boundaries

Writing to a calendar passes four independent checks, and the LLM never gets past the third on its own.

1. **OAuth scope.** Tokens get `school_content:read` by default; `calendar_imports:write` is optional and must be granted explicitly ([`excerpts/doorkeeper.rb`](excerpts/doorkeeper.rb)). Every tool calls `require_scope!` through `Tool.execute`; `draft_calendar_import` requires `calendar_imports:write`, while `get_calendar_import` needs only the read scope and only returns drafts created by the same user through the same OAuth application.
2. **School access.** `Context#school!` only resolves schools the user belongs to (all schools for site admins) and rejects schools where an administrator has not enabled AI access (`mcp_enabled?`).
3. **Calendar permissions.** `CalendarImport.authorize_draft!` re-checks AI access and membership, requires the school's events feature, and requires `Calendar#manageable_by?`: site admins, users with `school_admin` or `manage_events` at that school, a classroom's teachers, or a group's admins ([`excerpts/calendar.rb`](excerpts/calendar.rb)).
4. **Human review.** The tool only creates a draft. Each proposed event is normalized and validated (title, date/time parsing and validation, end after start, length limits, time zone); invalid items are saved with their errors and block approval until fixed or excluded. Exact duplicates are excluded by default, and overlaps are flagged. The draft expires after 24 hours. The tool returns a signed review URL whose token expires with the draft, and only the user who created the draft can view, edit, approve, or reject it. On approval, `approve!` locks the draft, re-runs `authorize_draft!` and item validation, and only then creates events in a single transaction.

Drafts that pass their expiry are marked expired; item details are purged after 30 days and import records are deleted after a year (`CleanupCalendarImportsJob`).

## Files to start with

MCP layer:

- [`app/models/fish_mcp/server.rb`](app/models/fish_mcp/server.rb) — MCP server and tool registration
- [`app/models/fish_mcp/context.rb`](app/models/fish_mcp/context.rb) — authenticated user, OAuth scopes, and school access
- [`app/models/fish_mcp/tool.rb`](app/models/fish_mcp/tool.rb) — shared tool behavior, authorization, errors, and responses
- [`app/models/fish_mcp/tools/draft_calendar_import.rb`](app/models/fish_mcp/tools/draft_calendar_import.rb) — human-reviewed write workflow
- [`app/models/fish_mcp/tools/search_events.rb`](app/models/fish_mcp/tools/search_events.rb) — scoped event search and structured results
- [`test/controllers/mcp_controller_test.rb`](test/controllers/mcp_controller_test.rb) — representative MCP request tests

Calendar import review flow:

- [`app/models/calendar_import.rb`](app/models/calendar_import.rb) — `create_draft!`, `authorize_draft!`, expiration, `approve!`, and `reject!`
- [`app/models/calendar_import_item.rb`](app/models/calendar_import_item.rb) — proposal parsing, validation, and duplicate/overlap detection
- [`app/controllers/calendar_imports_controller.rb`](app/controllers/calendar_imports_controller.rb) — signed, owner-only review page
- [`app/views/calendar_imports/show.html.erb`](app/views/calendar_imports/show.html.erb) — review, edit, approve, and reject UI
- [`app/jobs/cleanup_calendar_imports_job.rb`](app/jobs/cleanup_calendar_imports_job.rb) — expiration and data retention
- [`test/models/calendar_import_test.rb`](test/models/calendar_import_test.rb) and [`test/controllers/calendar_imports_controller_test.rb`](test/controllers/calendar_imports_controller_test.rb) — review-flow tests

Files in [`excerpts/`](excerpts/) are partial copies of larger FISH files, showing only the methods referenced above.

## Context

This code depends on models, fixtures, and infrastructure in the full FISH application that are intentionally not included here, so the tests cannot be run from this repository. The goal is to show a representative subsystem and the engineering decisions around it rather than publish the application itself.
