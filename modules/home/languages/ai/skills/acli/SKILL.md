---
name: acli
description: Use acli CLI for Atlassian operations - primarily Jira work item management, project operations, sprint tracking, and board management with JQL search. Also covers Confluence page/space/blog operations and a CQL search fallback (acli has no native Confluence search).
---
Use this skill to read or change Jira work items, projects, boards, sprints, and filters with `acli jira`, and to read or search Confluence. The task ends when the requested change is made or the requested data is printed.

Output flags work on most read commands: `--json` for parsing, `--csv` for export (search only), `--web` to open the browser.

Bulk selectors: most mutating commands accept one of `--key "K-1,K-2"`, `--jql "<query>"`, or `--filter <id>`.

## Authenticate

1. Run `acli jira auth status`.
   - Not logged in: run `acli jira auth login`, then retry.
   - Wrong account: run `acli jira auth switch`.

## Search and view work items

1. Search: `acli jira workitem search --jql "<query>" --fields "key,summary,status" --json`.
   - Add `--limit N`, `--paginate` for every page, or `--count` for the total only.
   - Include `summary` in `--fields`; `--fields "key"` alone returns null entries.
   - Search `--fields` rejects custom fields and `*all`. Read those with view.
   - Zero results: run `acli jira project view --key <KEY>` to confirm the key, then broaden the JQL.
   - JQL syntax error: remove clauses until it parses, then add them back one at a time.
2. View one item: `acli jira workitem view <KEY> --fields "*all" --json`.
   - `--fields` also accepts a list (`"summary,description,comment"`), `*navigable`, and exclusions (`"*navigable,-comment"`).
   - `failed to fetch work item details` is transient. Rerun the same command.

## Create a work item

1. Choose the method.
   - Only summary, project, type, assignee, description, labels, or parent: use flags (step 2).
   - Components, sprint, story points, or any custom field: use JSON (step 3). No flag exists for these.
2. Flag method:
   ```bash
   acli jira workitem create --summary "Title" --project TEAM --type Story \
     --assignee "user@example.com" --label "a,b" --parent TEAM-100 \
     --description "text" --json
   ```
   Pass the assignee as an email or `@me`. `--description-file <path>` reads the description from a file.
3. JSON method. Write a file in acli's own format, not the Jira REST format:
   ```json
   {
     "summary": "Title",
     "projectKey": "PROJ",
     "type": "Story",
     "parentIssueId": "PROJ-100",
     "assignee": "user@example.com",
     "labels": ["label1"],
     "description": {"type": "doc", "version": 1, "content": [
       {"type": "paragraph", "content": [{"type": "text", "text": "Description"}]}]},
     "additionalAttributes": {
       "components": [{"id": "12345"}],
       "customfield_10003": 5,
       "customfield_10701": 16378
     }
   }
   ```
   - `parentIssueId` takes the parent key string.
   - `description` takes Atlassian Document Format, not plain text.
   - `components` takes component IDs, not names.
   - Set the sprint field to the sprint ID integer and the story points field to a number.
   - Find custom field IDs with "Find custom field IDs" below.
   - Run `acli jira workitem create --generate-json` to print the full template.
4. Run `acli jira workitem create --from-json <file> --json`.
   - `Components is required`: copy a component ID from a similar item with `acli jira workitem view <KEY> --fields "*all" --json | jq '.fields.components'`, add it, and rerun.
   - `cannot be assigned issues`: remove the assignee, create, then run `acli jira workitem assign --key <KEY> --assignee "user@example.com"`.

## Find custom field IDs

1. Pick an existing item that has the fields set.
2. List its non-empty fields:
   ```bash
   acli jira workitem view PROJ-123 --fields "*all" --json | jq -r '
     .fields | to_entries[]
     | select(.value != null and .value != "" and .value != {} and .value != [])
     | "\(.key): \(.value | tostring | .[:200])"'
   ```
3. Match each field.
   - Sprint: a `customfield_*` holding objects with `boardId`, `state`, `startDate`, `endDate`.
   - Story points: a `customfield_*` holding a plain number.
   - Components: the standard `components` field.

## Find the active sprint

1. Run `acli jira board search --project <KEY> --json` and pick the project's board ID.
2. Run `acli jira board list-sprints --id <boardId> --state active,future --json`. Sprints are under `.sprints`.
   - The next sprint is the next same-named numbered sprint after the active one.
   - Skip holding sprints such as "Refinement" or "QA Validation Work".
3. Use the sprint `id` as the sprint field value when creating.
4. List a sprint's items with `acli jira sprint list-workitems --id <sprintId>`.

## Change work items

1. Before any `--jql` or `--filter` change, run the same query with `--count`, then with `--fields "key,summary"`, and confirm the matches.
2. Run the change. Add `--yes` to skip the prompt and `--ignore-errors` to continue past failures on many items.
   - Edit: `acli jira workitem edit --key K-1 [--summary S] [--description D | --description-file F] [--type T] [--labels a,b] [--remove-labels a] [--assignee E] [--remove-assignee]`.
   - Edit fields without flags: `acli jira workitem edit --generate-json`, fill it in, then `--from-json <file>`.
   - Transition: `acli jira workitem transition --key K-1 --status "In Progress"`. Use the status name exactly as the project's workflow shows it.
   - Assign: `acli jira workitem assign --key K-1 --assignee "user@example.com"`. `default` assigns the project default.
   - Comment: `acli jira workitem comment create --key K-1 --body "text"` or `--body-file F`. `--edit-last` replaces your last comment.
   - Comment list, update, delete: `acli jira workitem comment list --key K-1`, `comment update --key K-1 --comment-id ID --body "text"`, `comment delete --key K-1 --comment-id ID`.
   - Clone: `acli jira workitem clone --key K-1 --summary "New title"`.
   - Archive, unarchive, delete: `acli jira workitem archive|unarchive|delete --key K-1`.
   - Bulk create: `acli jira workitem create-bulk --generate-json`, fill it in, then `create-bulk --from-json <file>`.
3. View two or three changed items to confirm the result.
   - Permission error: run `acli jira workitem view <KEY>` to confirm read access, then report the failed action to the user.

## Other Jira commands

1. Projects: `acli jira project list [--limit N | --paginate | --recent]`, `acli jira project view --key TEAM`.
2. Filters: `acli jira filter list`, `filter search`, `filter get --id ID`.
3. Attachments, links, watchers, fields, dashboards, and project create/update/archive/delete: run `acli jira <group> --help` for the flags, e.g. `acli jira workitem link --help`.

## Confluence

1. Read a page: `acli confluence page view --id <ID> --json`. Other groups: `space`, `blog`, `auth`.
2. Search: acli has no search command. Run `confluence-search.sh` from this skill's directory.
   - Text: `confluence-search.sh "BFF client"`. Scope with `--space KEY`. Cap with `--limit N` (default 10).
   - Raw CQL: `confluence-search.sh --cql 'label = "bff" AND type = page ORDER BY lastmodified DESC'`.
   - Output is TSV `id<TAB>title<TAB>url`. Add `--json` for the raw response.
3. Pass the chosen ID to step 1.
   - `no entry for <host> in ~/.netrc`: tell the user to add a `machine thescore.atlassian.net` entry with their email and an API token from https://id.atlassian.com/manage-profile/security/api-tokens, then `chmod 600 ~/.netrc`.
   - The sandbox blocks reads of `~/.netrc`. When the script fails for that reason, report it to the user.
   - Set `CONFLUENCE_HOST` to search another site.
