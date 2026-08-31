/**
 * worklog — the first pi-brain EXTENSION (R1 / D-EXTRACT), living OUT of core in
 * the user's dotfiles. Ships:
 *   - descriptor: the type:worklog recall behavior (hidden, type-searchable).
 *   - registerTools: the worklog_add/list/get/update tools, the /brain-worklog
 *     command, and the flag-gated <brain-worklog-suggest> prompt fragment, all
 *     implemented over the injected BrainApi (read/write/index + appendLog +
 *     notifyWrite). No pi-brain-internal imports — self-contained.
 *
 * A work item is just a typed memory (type:worklog + wl_* attrs) with a
 * lifecycle; storage reuses the vault + index + sync via BrainApi. Enabled only
 * when config.json extensions.enabled includes "worklog".
 *
 * SAFETY: every tool body is wrapped; a failure returns an error result, never
 * throws into the agent loop.
 */
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  WORKLOG_TYPE,
  WL_STATUSES,
  WL_DEFAULT_STATUS,
  WL_STATUS_ATTR,
  WL_PRIORITY_ATTR,
  WL_LINEAR_ATTR,
  coerceStatus,
  coercePriority,
  priorityLabel,
  worklogAttrs,
  toWorklogItem,
  formatInbox,
  sortInbox,
  type WlStatus,
  type WorklogItem,
} from "./worklog.ts";

const WORKLOG_SUGGEST_ENV = "PI_BRAIN_WORKLOG_SUGGEST";

/** Is proactive worklog capture enabled (default off; the safety-valve exception)? */
function worklogSuggestEnabled(): boolean {
  const v = (process.env[WORKLOG_SUGGEST_ENV] ?? "").toLowerCase();
  return ["on", "1", "true", "yes"].includes(v);
}

type ToolResult = {
  content: { type: "text"; text: string }[];
  details?: Record<string, unknown>;
  isError?: boolean;
};
const textResult = (text: string): ToolResult => ({
  content: [{ type: "text", text }],
});
const errResult = (text: string): ToolResult => ({
  content: [{ type: "text", text }],
  isError: true,
});
const msg = (e: unknown): string => (e instanceof Error ? e.message : String(e));

/**
 * The minimal BrainApi surface this extension uses (locally declared so the
 * extension is SELF-CONTAINED / portable — no import into the pi-brain repo).
 * Structurally matches pi-brain's BrainApi; the host injects the real object.
 */
interface WlNode {
  id: string;
  title: string;
  scope: string;
  type?: string;
  body: string;
  updated?: string;
  created?: string;
}
interface BrainApi {
  getNote(id: string): WlNode | null;
  listByType(
    type: string,
    scopes?: string[],
  ): { node: WlNode; attrs: Record<string, string> }[];
  writeNote(fields: {
    title: string;
    body: string;
    type?: string;
    scope?: string;
    tags?: string[];
    attrs?: Record<string, string>;
  }): string;
  updateNote(
    id: string,
    patch: {
      title?: string;
      body?: string;
      tags?: string[];
      attrs?: Record<string, string>;
    },
  ): void;
  reindex(): void;
  appendLog(kind: string, line: string, opts?: { sessionId?: string }): void;
  notifyWrite(): void;
}

/** The R1 TypeDescriptor: type:worklog is hidden from recall + type-searchable. */
export const descriptor = {
  type: WORKLOG_TYPE,
  frontmatterKeys: [
    WL_STATUS_ATTR,
    WL_PRIORITY_ATTR,
    WL_LINEAR_ATTR,
    "wl_captured_from",
  ],
  recall: { inDefaultSearch: false, typeSearchable: true, hidden: true },
  owner: "extension:worklog",
};

/** List worklog items over the BrainApi (generalizes core's worklogNotes reader). */
function listWorklog(
  api: BrainApi,
  scope?: string,
  status?: WlStatus,
): WorklogItem[] {
  const scopes = scope ? [scope] : undefined;
  const items: WorklogItem[] = [];
  for (const { node, attrs } of api.listByType(WORKLOG_TYPE, scopes)) {
    const item = toWorklogItem(node, attrs);
    if (!item) continue;
    if (status && item.status !== status) continue;
    items.push(item);
  }
  return sortInbox(items);
}

/** Register the worklog tools/command/prompt-fragment against pi + the BrainApi. */
export function registerTools(pi: ExtensionAPI, api: BrainApi): void {
  const sessionId = (): string | undefined => {
    try {
      return (
        (pi as unknown as { sessionManager?: { getSessionId?: () => string } })
          .sessionManager?.getSessionId?.() ?? undefined
      );
    } catch {
      return undefined;
    }
  };

  pi.registerTool({
    name: "worklog_add",
    label: "Worklog Add",
    description:
      "Capture a work item (found-in-passing bug, follow-up, meeting action item, personal to-do) as a durable worklog note — FRICTION-FREE, deciding almost nothing at capture. Sets type:worklog + wl_status:triage and files it; priority and any Linear promotion are DEFERRED to triage. Write a RICH body: distill the relevant context so a FRESH session can pick it up as a plan-ready brief (what/why, file:line pointers, what's decided vs. deliberately-ambiguous, and a plain-English 'Next step:' line if known). Worklog notes are EXCLUDED from ordinary knowledge recall — use worklog_list/worklog_get to see them.",
    promptSnippet: "Capture a work item to the worklog (friction-free)",
    promptGuidelines: [
      "Capture-time discipline: DECIDE ALMOST NOTHING. Set a title, a scope guess, and a rich body; leave priority + Linear for triage.",
      "Distill context so a fresh session inherits a plan-ready brief — include file:line pointers and a plain-English 'Next step:' when known.",
      "Pick scope like any note: personal to-dos = global; project work = project:<name>.",
    ],
    parameters: Type.Object({
      title: Type.String({
        description: "Short imperative title, e.g. 'Fix null-deref in auth.py'.",
      }),
      body: Type.String({
        description:
          "The work item's rich markdown brief: description/context, file:line pointers, decided-vs-ambiguous, crosslinks, and a plain-English 'Next step:' line if known.",
      }),
      scope: Type.Optional(
        Type.String({
          description:
            "global (personal to-dos) | project:<name> (project work). Default global.",
        }),
      ),
      captured_from: Type.Optional(
        Type.String({
          description:
            "Provenance: where this came from, e.g. 'session <id>', 'meeting 2026-..', 'slack'.",
        }),
      ),
      priority: Type.Optional(
        Type.Number({
          description:
            "OPTIONAL Linear-mirrored priority 1=Urgent 2=High 3=Medium 4=Low (0/omit=unset). Usually leave UNSET at capture — decide it at triage.",
        }),
      ),
    }),
    async execute(_tc, params) {
      try {
        const p = params as {
          title?: string;
          body?: string;
          scope?: string;
          captured_from?: string;
          priority?: number;
        };
        if (!p.title?.trim() || !p.body?.trim())
          return errResult("title and body are required");
        const priority = coercePriority(p.priority);
        const attrs = worklogAttrs({
          status: WL_DEFAULT_STATUS,
          priority,
          capturedFrom: p.captured_from,
        });
        const sid = sessionId();
        const id = api.writeNote({
          title: p.title,
          body: p.body,
          scope: p.scope,
          type: WORKLOG_TYPE,
          attrs,
        });
        api.reindex();
        api.notifyWrite();
        api.appendLog("worklog", `add ${id} "${p.title}" scope=${p.scope ?? "global"}`, {
          sessionId: sid,
        });
        return {
          content: [
            {
              type: "text" as const,
              text: `Captured work item [${id}] (status=triage, priority=${priorityLabel(priority)}). It's excluded from knowledge recall; see it via /brain-worklog or worklog_list.`,
            },
          ],
          details: { id },
        };
      } catch (e) {
        return errResult(`worklog_add failed: ${msg(e)}`);
      }
    },
  });

  pi.registerTool({
    name: "worklog_list",
    label: "Worklog List",
    description:
      "List the worklog inbox — all captured work items, grouped by scope and sorted by priority then age (stale items float up). This is the 'process my inbox' / triage view. Optionally filter by scope or lifecycle status (triage|ready|doing|done|dropped|blocked). Terminal items (done/dropped) are hidden unless include_terminal is set.",
    promptSnippet: "List the worklog inbox",
    parameters: Type.Object({
      scope: Type.Optional(
        Type.String({ description: "Filter to one scope (global | project:<name>)." }),
      ),
      status: Type.Optional(
        Type.String({
          description: `Filter to one lifecycle status: ${WL_STATUSES.join(" | ")}.`,
        }),
      ),
      include_terminal: Type.Optional(
        Type.Boolean({
          description:
            "Include done/dropped items (default false — the inbox is the active pile).",
        }),
      ),
    }),
    async execute(_tc, params) {
      try {
        const p = params as {
          scope?: string;
          status?: string;
          include_terminal?: boolean;
        };
        const status =
          p.status && (WL_STATUSES as readonly string[]).includes(p.status)
            ? (p.status as WlStatus)
            : undefined;
        if (p.status && !status)
          return errResult(
            `Unknown status '${p.status}'. Valid: ${WL_STATUSES.join(", ")}.`,
          );
        const items = listWorklog(api, p.scope, status);
        return textResult(formatInbox(items, !!p.include_terminal));
      } catch (e) {
        return errResult(`worklog_list failed: ${msg(e)}`);
      }
    },
  });

  pi.registerTool({
    name: "worklog_get",
    label: "Worklog Get",
    description:
      "Read a single work item in full (its rich brief + wl_* state) by id — the plan-ready context a fresh session inherits before diving into or triaging it.",
    promptSnippet: "Read a worklog item by id",
    parameters: Type.Object({
      id: Type.String({ description: "Work item id (from worklog_list)." }),
    }),
    async execute(_tc, params) {
      try {
        const p = params as { id?: string };
        if (!p.id?.trim()) return errResult("id is required");
        const node = api.getNote(p.id.trim());
        if (!node || node.type !== WORKLOG_TYPE)
          return errResult(
            `No worklog item with id ${p.id}. Use worklog_list to find it.`,
          );
        const item = toWorklogItem(
          { ...node, created: (node as { created?: string }).created },
          // attrs come from listByType elsewhere; fetch via a 1-item listByType scan
          listWorklogAttrs(api, node.id),
        );
        if (!item) return errResult(`Item ${p.id} is not a worklog note.`);
        const meta = [
          `status: ${item.status}`,
          `priority: ${priorityLabel(item.priority)}`,
          item.linear ? `linear: ${item.linear}` : null,
          item.capturedFrom ? `captured_from: ${item.capturedFrom}` : null,
          `scope: ${item.scope}`,
          item.created ? `created: ${item.created}` : null,
          item.updated ? `updated: ${item.updated}` : null,
        ]
          .filter(Boolean)
          .join("  ·  ");
        return textResult(`# ${item.title}  [${item.id}]\n${meta}\n\n${item.body}`);
      } catch (e) {
        return errResult(`worklog_get failed: ${msg(e)}`);
      }
    },
  });

  pi.registerTool({
    name: "worklog_update",
    label: "Worklog Update",
    description:
      "Update a work item IN PLACE (D2 CRUD): change its lifecycle status (triage→ready→doing→done, or the dropped/blocked off-ramps), set its priority, attach a Linear back-link once promoted, and/or flesh out the body brief. Only pass fields you want to change. This is a DIRECT write (user-in-the-loop); use worklog_update with status:dropped to drop an item.",
    promptSnippet: "Update a worklog item (status/priority/linear/body)",
    promptGuidelines: [
      "Autonomy scales with reversibility (D5c): freely draft/extend the body (it's just text); GATE irreversible/external moves (dropping an item, a priority the user didn't confirm, creating the Linear issue).",
      "Promotion to Linear MOVES the item out of the active board (D4): set wl_linear + status:done once the Linear issue is the source of truth.",
    ],
    parameters: Type.Object({
      id: Type.String({ description: "Work item id (from worklog_list)." }),
      status: Type.Optional(
        Type.String({
          description: `New lifecycle status: ${WL_STATUSES.join(" | ")}. (status:dropped is the drop path.)`,
        }),
      ),
      priority: Type.Optional(
        Type.Number({
          description:
            "New priority 1=Urgent 2=High 3=Medium 4=Low (0=unset).",
        }),
      ),
      linear: Type.Optional(
        Type.String({
          description:
            "Linear back-link once promoted, e.g. 'AIRCORE-1032' or its URL (frontmatter only, never in code).",
        }),
      ),
      title: Type.Optional(Type.String({ description: "New title. Omit to keep." })),
      body: Type.Optional(
        Type.String({
          description: "New/replacement body brief (markdown). Omit to keep current.",
        }),
      ),
    }),
    async execute(_tc, params) {
      try {
        const p = params as {
          id?: string;
          status?: string;
          priority?: number;
          linear?: string;
          title?: string;
          body?: string;
        };
        if (!p.id?.trim()) return errResult("id is required");
        const found = api.getNote(p.id.trim());
        if (!found || found.type !== WORKLOG_TYPE)
          return errResult(
            `No worklog item with id ${p.id}. Use worklog_list to find it.`,
          );
        if (p.status && !(WL_STATUSES as readonly string[]).includes(p.status))
          return errResult(
            `Unknown status '${p.status}'. Valid: ${WL_STATUSES.join(", ")}.`,
          );
        const attrPatch: Record<string, string> = {};
        if (p.status) attrPatch[WL_STATUS_ATTR] = coerceStatus(p.status);
        if (p.priority !== undefined)
          attrPatch[WL_PRIORITY_ATTR] = String(coercePriority(p.priority));
        if (p.linear?.trim()) attrPatch[WL_LINEAR_ATTR] = p.linear.trim();
        api.updateNote(p.id.trim(), {
          title: p.title,
          body: p.body,
          attrs: Object.keys(attrPatch).length ? attrPatch : undefined,
        });
        api.reindex();
        api.notifyWrite();
        const sid = sessionId();
        const changed = [
          p.status ? `status=${p.status}` : null,
          p.priority === undefined ? null : `priority=${coercePriority(p.priority)}`,
          p.linear ? `linear=${p.linear}` : null,
          p.title === undefined ? null : "title",
          p.body === undefined ? null : "body",
        ]
          .filter(Boolean)
          .join(" ");
        api.appendLog("worklog", `update ${p.id.trim()} ${changed}`.trim(), {
          sessionId: sid,
        });
        return {
          content: [
            {
              type: "text" as const,
              text: `Updated work item [${p.id}]${changed ? ` (${changed})` : ""}.`,
            },
          ],
          details: { id: p.id },
        };
      } catch (e) {
        return errResult(`worklog_update failed: ${msg(e)}`);
      }
    },
  });

  pi.registerCommand("brain-worklog", {
    description:
      "pi-brain: list the worklog inbox (captured work items). Optional arg: a status (triage|ready|doing|done|dropped|blocked), a scope (global|project:<name>), or 'all' to include done/dropped.",
    handler: async (args: string, ctx: { ui?: { notify?: (m: string, k?: string) => void } }) => {
      try {
        const arg = (args ?? "").trim();
        let scope: string | undefined;
        let status: WlStatus | undefined;
        let includeTerminal = false;
        if (arg) {
          if (arg === "all") includeTerminal = true;
          else if ((WL_STATUSES as readonly string[]).includes(arg)) {
            status = arg as WlStatus;
            if (arg === "done" || arg === "dropped") includeTerminal = true;
          } else if (arg.includes(":") || arg === "global") scope = arg;
          else {
            ctx.ui?.notify?.(
              `brain-worklog: unrecognized arg '${arg}'. Use a status (${WL_STATUSES.join("|")}), a scope (global|project:<name>), or 'all'.`,
              "error",
            );
            return;
          }
        }
        const items = listWorklog(api, scope, status);
        ctx.ui?.notify?.(formatInbox(items, includeTerminal), "info");
      } catch (e) {
        ctx.ui?.notify?.(`brain: worklog list failed: ${msg(e)}`, "error");
      }
    },
  });

  // Flag-gated proactive-capture nudge (default off — UX-intrusive). Mirrors the
  // old core <brain-worklog-suggest> fragment.
  pi.on?.("before_agent_start", async (event: { systemPrompt: string }) => {
    try {
      if (!worklogSuggestEnabled()) return;
      return {
        systemPrompt:
          event.systemPrompt +
          `\n\n<brain-worklog-suggest>\nPROACTIVE WORKLOG CAPTURE is ON. If you notice a ` +
          `capturable work item in passing — a bug you're not fixing now, a follow-up, a ` +
          `deferred TODO — OFFER to log it to the user's worklog ("want me to log that?"). Only ` +
          `capture on an explicit yes (approval-gated, never silent); use worklog_add with ` +
          `capture-time discipline (title + rich body + a 'Next step:' if known; leave ` +
          `priority unset). Don't derail the current task to hunt for items.\n</brain-worklog-suggest>`,
      };
    } catch {
      return;
    }
  });
}

/** Fetch a single worklog note's attrs via a scoped listByType scan. */
function listWorklogAttrs(api: BrainApi, id: string): Record<string, string> {
  for (const { node, attrs } of api.listByType(WORKLOG_TYPE)) {
    if (node.id === id) return attrs;
  }
  return {};
}

export default { descriptor, registerTools };
