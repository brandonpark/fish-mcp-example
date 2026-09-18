# FISH MCP Code Sample

Selected production code from **FISH**, a school management and communication platform developed by Brandon McCandlish.

This repository is a focused code sample extracted from the larger FISH Rails application. It demonstrates the architecture of FISH's Model Context Protocol (MCP) integration; it is not intended to be a standalone or runnable version of FISH. Supporting models, application configuration, and unrelated product code have intentionally been omitted.


## What this demonstrates

The MCP layer gives an authenticated user's LLM access to narrowly scoped FISH tools while relying on the existing Rails application for authorization, business rules, and data access.

A deliberate design decision is that an LLM cannot directly commit certain changes to FISH. For example, `DraftCalendarImport` allows an LLM to identify and propose calendar events, but creates an expiring draft for human review rather than directly adding those events to a school or group calendar.

An admin or coach could use their LLM of choice to parse an email containing upcoming JV basketball games, create a proposed calendar import, and then review and commit those events inside FISH.

## Files to start with

- `app/models/fish_mcp/server.rb` — MCP server and tool registration
- `app/models/fish_mcp/context.rb` — authenticated user, OAuth scopes, and school access
- `app/models/fish_mcp/tool.rb` — shared tool behavior, authorization, errors, and responses
- `app/models/fish_mcp/tools/draft_calendar_import.rb` — human-reviewed write workflow
- `app/models/fish_mcp/tools/search_events.rb` — scoped event search and structured results
- `test/controllers/mcp_controller_test.rb` — representative MCP request tests

## Context

This code depends on models and infrastructure in the full FISH application that are intentionally not included here. The goal of this repository is to show a representative production subsystem and the engineering decisions around it rather than publish the application itself.
