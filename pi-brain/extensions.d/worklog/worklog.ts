/**
 * pi-brain worklog: friction-free work-item capture, triage & (later) async
 * execution. A work item is NOT a new store — it is an ordinary vault note with
 * `type: worklog` and a small `wl_*` frontmatter contract (D1). This module holds
 * the type/vocabulary constants, capture-time defaults, the WorklogItem view over
 * a note, and PURE list/format/sort helpers. Storage reuses writeNote/updateNote;
 * exclusion from ordinary knowledge recall lives in the index (index-db hiddenIds).
 *
 * Design authority: handoff/plan-worklog.md decision log (D1–D9). Notably:
 *  - D2: a dedicated CRUD toolset (add/list/get/update/drop), not memory_write.
 *  - D4: TWO axes only — lifecycle state + Linear-mirrored priority — plus a
 *        plain-English "next step" in the BODY (no disposition enum).
 *  - D9/LE-2: worklog writes are DIRECT (the user is in the loop live), not journaled.
 *  - 2b: capture-time discipline — DECIDE ALMOST NOTHING (status=triage, priority
 *        unset, a scope guess, a title, the body, provenance).
 *
 * SAFETY: pure functions; total; never throw.
 */

/**
 * Minimal structural view of an indexed note (self-contained: the extension does
 * not import pi-brain internals). Matches the fields toWorklogItem reads off the
 * BrainApi's returned nodes.
 */
interface GraphNode {
 id: string;
 title: string;
 scope: string;
 type?: string;
 body: string;
 updated?: string;
 created?: string;
}

/** The note `type:` that marks a work item. Excluded from knowledge recall (D1). */
export const WORKLOG_TYPE = "worklog";

/** Frontmatter attr keys (D9/LE-4: keep the `wl_` prefix across the board). */
export const WL_STATUS_ATTR = "wl_status";
export const WL_PRIORITY_ATTR = "wl_priority";
export const WL_LINEAR_ATTR = "wl_linear";
export const WL_CAPTURED_FROM_ATTR = "wl_captured_from";
/**
 * Kind (LE-5): what CATEGORY of work this item is. Default `task` (any ordinary
 * captured work). `pr-review` marks a PR-review request as its own tracked work
 * unit — so "reviews I owe" is queryable and a re-swept PR doesn't duplicate.
 */
export const WL_KIND_ATTR = "wl_kind";
/**
 * A stable external REFERENCE that uniquely identifies the underlying work, so a
 * repeated capture (e.g. re-sweeping Slack/GitHub) can dedupe on it. For a
 * `pr-review` item this is the PR URL (or `owner/repo#number`).
 */
export const WL_REF_ATTR = "wl_ref";

/**
 * Axis 1 — lifecycle state (D4). Start minimal; add states only if the machine
 * demonstrably needs them. `triage` = captured, not yet decided (the default at
 * capture); `ready` = we know what to do, not started; `doing`; `done`; plus the
 * two off-ramps `dropped` and `blocked`.
 */
export const WL_STATUSES = [
 "triage",
 "ready",
 "doing",
 "done",
 "dropped",
 "blocked",
] as const;
export type WlStatus = (typeof WL_STATUSES)[number];

/** The default lifecycle state at capture time (2b). */
export const WL_DEFAULT_STATUS: WlStatus = "triage";

/** States that are OFF the active board (no longer awaiting triage/work). */
export const WL_TERMINAL_STATUSES: readonly WlStatus[] = ["done", "dropped"];

/**
 * Work-item KIND (LE-5). `task` is any ordinary captured work (the default);
 * `pr-review` is a PR-review request tracked as its own unit. Add kinds only when
 * a category needs distinct handling/queryability.
 */
export const WL_KINDS = ["task", "pr-review"] as const;
export type WlKind = (typeof WL_KINDS)[number];
export const WL_DEFAULT_KIND: WlKind = "task";

/** True if `k` is a recognized work-item kind. */
export function isWlKind(k: string | undefined): k is WlKind {
 return !!k && (WL_KINDS as readonly string[]).includes(k);
}

/** Coerce an arbitrary string to a valid WlKind, defaulting to task. */
export function coerceKind(k: string | undefined): WlKind {
 return isWlKind(k) ? k : WL_DEFAULT_KIND;
}

/**
 * Axis 2 — priority (D4): mirror Linear's four-tier system so promotion maps
 * cleanly. 0 = unset (the capture default), 1 = Urgent, 2 = High, 3 = Medium,
 * 4 = Low.
 */
export type WlPriority = 0 | 1 | 2 | 3 | 4;
export const WL_DEFAULT_PRIORITY: WlPriority = 0;
const WL_PRIORITY_LABELS: Record<WlPriority, string> = {
 0: "unset",
 1: "Urgent",
 2: "High",
 3: "Medium",
 4: "Low",
};

/** True if `s` is a recognized lifecycle state. */
export function isWlStatus(s: string | undefined): s is WlStatus {
 return !!s && (WL_STATUSES as readonly string[]).includes(s);
}

/** Coerce an arbitrary string/number to a valid WlStatus, defaulting to triage. */
export function coerceStatus(s: string | undefined): WlStatus {
 return isWlStatus(s) ? s : WL_DEFAULT_STATUS;
}

/** Coerce an arbitrary value to a valid priority tier (0..4), defaulting to unset. */
export function coercePriority(p: string | number | undefined): WlPriority {
 const n = typeof p === "number" ? p : Number.parseInt(String(p ?? ""), 10);
 if (Number.isFinite(n) && n >= 1 && n <= 4) return n as WlPriority;
 return WL_DEFAULT_PRIORITY;
}

/** Human label for a priority tier, e.g. "2 (High)" / "unset". */
export function priorityLabel(p: WlPriority): string {
 return p === 0 ? "unset" : `${p} (${WL_PRIORITY_LABELS[p]})`;
}

/** A work item — a projection of a `type: worklog` note + its `wl_*` attrs. */
export interface WorklogItem {
 id: string;
 title: string;
 scope: string;
 status: WlStatus;
 priority: WlPriority;
 /** `AIRCORE-<n>` or a URL, once promoted to Linear (frontmatter only, never code). */
 linear?: string;
 /** Work-item kind (LE-5): `task` (default) or `pr-review`. */
 kind: WlKind;
 /** Stable external ref that uniquely identifies the work (e.g. a PR URL). */
 ref?: string;
 /** Provenance: "session X", "meeting 2026-…", "slack". */
 capturedFrom?: string;
 created?: string;
 updated?: string;
 /** The free-text body (description + plain-English "Next step:"). */
 body: string;
}

/**
 * Build a WorklogItem view from a note's indexed fields + its EAV attrs. Total:
 * missing/garbled attrs coerce to their capture-time defaults. Returns undefined
 * only when the note is not a worklog note (defensive — callers should pre-filter).
 */
export function toWorklogItem(
 node: Pick<
  GraphNode,
  "id" | "title" | "scope" | "type" | "body" | "updated"
 > & { created?: string },
 attrs: Record<string, string>,
): WorklogItem | undefined {
 if (node.type !== WORKLOG_TYPE) return undefined;
 return {
  id: node.id,
  title: node.title,
  scope: node.scope,
  status: coerceStatus(attrs[WL_STATUS_ATTR]),
  priority: coercePriority(attrs[WL_PRIORITY_ATTR]),
  linear: attrs[WL_LINEAR_ATTR] || undefined,
  kind: coerceKind(attrs[WL_KIND_ATTR]),
  ref: attrs[WL_REF_ATTR] || undefined,
  capturedFrom: attrs[WL_CAPTURED_FROM_ATTR] || undefined,
  created: node.created,
  updated: node.updated,
  body: node.body,
 };
}

/**
 * Assemble the `wl_*` attrs map for a write/update. Only defined fields are
 * emitted; capture-time discipline (2b) means `worklog_add` passes just status
 * (triage) and maybe capturedFrom, leaving priority/linear unset.
 */
export function worklogAttrs(input: {
 status?: WlStatus;
 priority?: WlPriority;
 linear?: string;
 kind?: WlKind;
 ref?: string;
 capturedFrom?: string;
}): Record<string, string> {
 const out: Record<string, string> = {};
 if (input.status) out[WL_STATUS_ATTR] = input.status;
 if (input.priority !== undefined && input.priority !== 0)
  out[WL_PRIORITY_ATTR] = String(input.priority);
 if (input.linear) out[WL_LINEAR_ATTR] = input.linear;
 // Only emit kind when it's non-default, keeping ordinary task notes clean.
 if (input.kind && input.kind !== WL_DEFAULT_KIND)
  out[WL_KIND_ATTR] = input.kind;
 if (input.ref) out[WL_REF_ATTR] = input.ref;
 if (input.capturedFrom) out[WL_CAPTURED_FROM_ATTR] = input.capturedFrom;
 return out;
}

/**
 * Triage-inbox sort (Level-1 scan, D5): highest priority first (1=Urgent before
 * 4=Low; unset=0 sinks to the bottom), then oldest-first within a tier (stale
 * items float up so they get pruned). Terminal states (done/dropped) sort last.
 * Stable + total.
 */
export function sortInbox(items: WorklogItem[]): WorklogItem[] {
 const prioRank = (p: WlPriority) => (p === 0 ? 99 : p); // unset sinks
 const terminal = (s: WlStatus) =>
  (WL_TERMINAL_STATUSES as readonly string[]).includes(s) ? 1 : 0;
 return [...items].sort((a, b) => {
  const t = terminal(a.status) - terminal(b.status);
  if (t !== 0) return t;
  const p = prioRank(a.priority) - prioRank(b.priority);
  if (p !== 0) return p;
  // oldest first (created ascending); missing created sorts last
  const ca = a.created ?? "\uffff";
  const cb = b.created ?? "\uffff";
  return ca < cb ? -1 : ca > cb ? 1 : 0;
 });
}

/** Which statuses count as the ACTIVE inbox (awaiting triage or in-flight). */
export function isActive(status: WlStatus): boolean {
 return !(WL_TERMINAL_STATUSES as readonly string[]).includes(status);
}

/**
 * Render a compact one-line summary of a work item for the `/brain-worklog`
 * inbox list and the worklog_list tool. e.g.
 *   [01H…] ★2 (High) doing · project:nemo-platform · Fix null-deref in auth.py  (→ AIRCORE-1032)
 */
export function formatItemLine(item: WorklogItem): string {
 const prio = item.priority === 0 ? "" : `p${item.priority} `;
 const linear = item.linear ? `  (→ ${item.linear})` : "";
 const kind = item.kind && item.kind !== WL_DEFAULT_KIND ? `〈${item.kind}〉 ` : "";
 return `[${item.id}] ${kind}${prio}${item.status} · ${item.scope} · ${item.title}${linear}`;
}

/**
 * Group items by scope and render the inbox as a grouped, sorted text block. Pure
 * (no I/O) so it's trivially testable and reusable by both the tool and command.
 * `includeTerminal` controls whether done/dropped items are shown (default off —
 * the inbox is about the active pile).
 */
export function formatInbox(
 items: WorklogItem[],
 includeTerminal = false,
): string {
 const shown = includeTerminal
  ? items
  : items.filter((i) => isActive(i.status));
 if (!shown.length) return "Worklog inbox is empty. 🎉";
 const byScope = new Map<string, WorklogItem[]>();
 for (const it of sortInbox(shown)) {
  const arr = byScope.get(it.scope) ?? [];
  arr.push(it);
  byScope.set(it.scope, arr);
 }
 const parts: string[] = [];
 for (const [scope, arr] of [...byScope.entries()].sort()) {
  parts.push(`### ${scope} (${arr.length})`);
  for (const it of arr) parts.push(`- ${formatItemLine(it)}`);
 }
 const total = shown.length;
 return `Worklog inbox — ${total} item${total === 1 ? "" : "s"}:\n\n${parts.join("\n")}`;
}
