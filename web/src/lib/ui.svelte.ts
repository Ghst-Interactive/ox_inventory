/**
 * Transient UI state: whether the inventory is on screen, what the tooltip is describing,
 * and what the context menu is open on. The latter two were Redux slices; neither needs
 * anything a rune cannot do.
 */

import type { Inventory, SlotWithItem } from '../typings';

/**
 * Whether the two panes are on screen.
 *
 * This lived as local state inside Inventory.svelte until the hotbar needed it. A
 * persistent hotbar has to stand down while the inventory is open — it sits at the
 * bottom of the same viewport and would draw a second copy of slots 1-5 underneath the
 * pane that already shows them. Duplicating the four NUI listeners in a second component
 * would leave two answers to one question, so the answer moved here instead.
 */
export const ui = $state<{ inventoryOpen: boolean; equippedSlot: number | null }>({
  inventoryOpen: false,
  /**
   * The player-inventory slot currently in their hands, or null for empty-handed.
   *
   * Announced by client.lua's main interval rather than by whatever changed the weapon,
   * because `currentWeapon` is assigned from a dozen paths and one of them would have been
   * missed. Costs up to a tick of latency on a marker that is purely informational.
   */
  equippedSlot: null,
});

export const tooltip = $state<{
  item: SlotWithItem | null;
  inventoryType: Inventory['type'] | null;
  /**
   * The slot's rect at the moment the tooltip opened.
   *
   * The React build re-anchored to the cursor on every mousemove, so the tooltip slid
   * around while you were reading it. Anchoring to the slot instead holds it still —
   * the deliberate change here, and the reason this is a rect rather than a point.
   */
  anchor: DOMRect | null;
}>({ item: null, inventoryType: null, anchor: null });

export function openTooltip(item: SlotWithItem, inventoryType: Inventory['type'], anchor: DOMRect) {
  tooltip.item = item;
  tooltip.inventoryType = inventoryType;
  tooltip.anchor = anchor;
}

export function closeTooltip() {
  tooltip.item = null;
  tooltip.anchor = null;
}

export const contextMenu = $state<{ item: SlotWithItem | null; anchor: DOMRect | null }>({
  item: null,
  anchor: null,
});

/** Opened at the pointer, so the anchor is a zero-size rect at the click coordinates. */
export function openContextMenu(item: SlotWithItem, x: number, y: number) {
  contextMenu.item = item;
  contextMenu.anchor = new DOMRect(x, y, 0, 0);
}

export function closeContextMenu() {
  contextMenu.item = null;
  contextMenu.anchor = null;
}

/**
 * The count prompt: "how many of these?" — a centred dialog, for Split AND Drop.
 *
 * It was anchored at the pointer until the design walk (2026-09-05), which made the three
 * questions one shape: a centred kit `Panel` per verb, drawn by `CountDialog`. The `x, y`
 * this used to take are gone rather than ignored, because an argument nothing reads is a
 * thing the next caller fills in carefully and wrongly.
 *
 * Opened by releasing a drag with Alt held (Split) or by choosing Drop on a stack of more
 * than one from the context menu. The alternatives already in the UI are the amount box,
 * which has to be filled in *before* the drag and applies to every move until you clear
 * it, and shift-drag, which only ever gives you half — so moving 7 of a stack of 40 meant
 * typing 7, dragging, then remembering to clear the box.
 *
 * `verb` names the button — "Split" or "Drop" — the one difference between the two
 * callers; everything else (the digit, the slider, the quick chips) is the one
 * `CountControl` the design walk asked for, shared with the give picker as well.
 *
 * `commit` is supplied by whoever opened the prompt rather than resolved here. The rules
 * for what a drop means differ per pane (a shop purchase is not a move, and a crafting
 * bench counts iterations rather than items), and all three already live in actions.ts.
 * Storing the closure keeps that knowledge out of this file.
 */
export const countPrompt = $state<{
  open: boolean;
  label: string;
  verb: string;
  /** The one line under the title saying where the items go. The panel's blurb. */
  blurb: string;
  max: number;
  commit: ((count: number) => void) | null;
}>({ open: false, label: '', verb: '', blurb: '', max: 0, commit: null });

export function openCountPrompt(
  label: string,
  verb: string,
  blurb: string,
  max: number,
  commit: (count: number) => void,
) {
  countPrompt.label = label;
  countPrompt.verb = verb;
  countPrompt.blurb = blurb;
  countPrompt.max = max;
  countPrompt.commit = commit;
  countPrompt.open = true;
}

export function closeCountPrompt() {
  countPrompt.open = false;
  countPrompt.commit = null;
}

/**
 * The weapon whose attachments are being looked at, by slot in the player's inventory.
 *
 * A slot number rather than the item, deliberately. Removing a component is answered by
 * Lua with a bare acknowledgement and the real change arrives later as refreshSlots, so
 * the panel has to read live from the store to see a part leave. Holding the item itself
 * would be holding a copy made before the removal.
 */
export const weaponPanel = $state<{ slot: number | null }>({ slot: null });

export function openWeaponPanel(slot: number) {
  weaponPanel.slot = slot;
}

export function closeWeaponPanel() {
  weaponPanel.slot = null;
}

/**
 * Who to hand the item to, when more than one person is standing there.
 *
 * This choice already existed — client.lua built the same list and showed it through
 * `lib.registerMenu`, which draws ox_lib's menu over the top of the open inventory in a
 * different visual language, with the inventory still sitting behind it. The list is now
 * fetched by the UI and offered in its own window; the ox_lib path stays as the fallback
 * for anything that reaches `giveItem` without going through here.
 */
export interface GiveTarget {
  /** Server id, which is what giveItemToTarget expects. */
  id: number;
  label: string;
}

export const givePicker = $state<{
  open: boolean;
  slot: number;
  count: number;
  targets: GiveTarget[];
}>({ open: false, slot: 0, count: 0, targets: [] });

export function openGivePicker(slot: number, count: number, targets: GiveTarget[]) {
  givePicker.slot = slot;
  givePicker.count = count;
  givePicker.targets = targets;
  givePicker.open = true;
}

export function closeGivePicker() {
  givePicker.open = false;
  givePicker.targets = [];
}

/**
 * THE SELECTED SLOT, and why this exists at all.
 *
 * `Use`, `Give` and `Drop` in the control column were drop targets and nothing else: a `<button>`
 * with a `droppable` action and no `onclick`, so pressing one did nothing at all. That is the
 * worst state a control can be in -- it looks pressable, it highlights on hover, and it is inert.
 *
 * A bare left-click on a slot did nothing either (ctrl and alt were taken, a plain click was not),
 * so it is free to mean *this one*. The verbs then act on the selection, and the amount box above
 * them -- which until now only ever affected a drag -- starts meaning something for a press too.
 *
 * Kept here rather than in `inv` because it is a fact about the screen, not about the inventory:
 * it does not survive the pane closing and nothing on the server has an opinion about it.
 */
export const selection = $state<{ inventory: string | null; slot: number | null }>({
  inventory: null,
  slot: null,
});

/**
 * The two reference panels the player's own pane can raise: the controls sheet and the settings.
 *
 * **Held here for the same reason `weaponPanel` is: something outside them has to know one is up.**
 * They were two `$state` booleans inside `InventoryGrid`, bound down into the components, and that
 * was defensible while the only thing that cared was the pane that owned them. It stopped being
 * true when `Inventory.svelte` learned to latch Escape — every dialog in this resource takes the
 * key on keydown and the window takes it on keyup, so a press that closes a dialog closes the
 * window behind it unless the window can tell a dialog was up. `dialogUp` reads this; a flag it
 * cannot see is a dialog whose Escape still takes the inventory with it, which is exactly what
 * these two did.
 *
 * One pair rather than one per pane, which is what the flags already were in practice:
 * `InventoryGrid` gated both on `ownPane`, so only the player's own bag ever raised them.
 */
export const panels = $state<{ help: boolean; settings: boolean }>({ help: false, settings: false });

export function closePanels() {
  panels.help = false;
  panels.settings = false;
}

/** Clicking the selected slot again clears it, so there is a way out that is not a verb. */
export function selectSlot(inventory: string, slot: number) {
  if (selection.inventory === inventory && selection.slot === slot) return clearSelection();

  selection.inventory = inventory;
  selection.slot = slot;
}

export function clearSelection() {
  selection.inventory = null;
  selection.slot = null;
}
