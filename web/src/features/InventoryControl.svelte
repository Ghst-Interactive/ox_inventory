<script lang="ts">
  import { tick } from 'svelte';
  import { dropToGround, onGive, onUse } from '../lib/actions';
  import { droppable } from '../lib/dnd.svelte';
  import { isSlotWithItem } from '../lib/helpers';
  import { inv } from '../lib/inventory.svelte';
  import { fetchNui } from '../lib/nui';
  import { locale } from '../lib/state.svelte';
  import { clearSelection, selection } from '../lib/ui.svelte';
  import { InventoryType, type DragSource, type SlotWithItem } from '../typings';

  /**
   * The centre column: how many of a thing to move, and the three verbs.
   *
   * Use, Give and Drop are drop targets rather than buttons you press with a slot selected —
   * you drag an item onto them. They are also the only interactive surface outside the
   * grid, which is why the store's concurrency guard cannot rely on the grid's
   * pointer-events being switched off.
   *
   * ## Drop is here because the other two are
   *
   * It was reachable only from the right-click menu, and so are Use and Give — so "you can get at
   * it another way" never distinguished it. What did distinguish it was the gesture: the whole
   * point of this column is that a bag has three exits you can throw a thing at, and one of the
   * three was missing. Dragging onto DROP is the shortest path to putting something down, and it
   * is the one a player reaches for while holding the item already.
   *
   * `dropToGround` is shared with the menu rather than reimplemented, so both ask how many in
   * the same circumstances. Close stays a button: it is not somewhere an item can go.
   *
   * ## They are also pressable now, and they were not
   *
   * Each was a `<button>` carrying a `droppable` and no `onclick` — it lit on hover, it looked
   * exactly like the Close button beside it, and pressing it did nothing whatsoever. A control
   * that cannot be pressed must not be shaped like one.
   *
   * They act on the selected slot (`lib/ui.svelte.ts`), which a bare left-click sets — the one
   * gesture on a slot that used to do nothing. With nothing selected they are `disabled`, so the
   * answer to "why did that do nothing" is on the button rather than in the player's head. The
   * amount box above them has always fed `onGive` and `onDrop`; now it feeds a press too.
   *
   * ## The help and settings buttons are gone from here
   *
   * They sat under the verbs as bare `--color-dim` glyphs with no plate, in the gap between the
   * panes — over the moving world, in the one ink colour this tree's own rule says never survives
   * it. They are ghost buttons in the player pane's header now, beside Backpack and Tidy, where
   * there is a surface under them.
   */

  let input = $state<HTMLInputElement | null>(null);

  /**
   * The amount box is formatted with thousands separators as you type, which means the
   * caret has to be restored by hand after every edit — replacing the value moves it to
   * the end. The trick, carried over from the React build, is to count *digits* before
   * the caret rather than characters, then map that back to a character offset once the
   * new string exists. Separators shift, digits do not.
   */
  const formatAmount = (n: number) => (n > 0 ? n.toLocaleString('en-US') : '0');
  const digitsOnly = (s: string) => s.replace(/\D/g, '');
  const countDigitsBefore = (s: string, index: number) => digitsOnly(s.substring(0, index)).length;

  let value = $state(formatAmount(inv.itemAmount));

  async function commitValue(raw: string, cursorIndex: number) {
    const digitsBefore = countDigitsBefore(raw, cursorIndex);
    const parsed = parseInt(digitsOnly(raw), 10) || 0;

    value = formatAmount(parsed);
    inv.itemAmount = parsed;

    await tick();
    if (!input) return;

    let position = 0;
    let seen = 0;

    for (let i = 0; i < value.length && seen < digitsBefore; i++) {
      if (/\d/.test(value[i])) seen++;
      position++;
    }

    input.setSelectionRange(position, position);
  }

  function oninput(event: Event) {
    const el = event.currentTarget as HTMLInputElement;
    commitValue(el.value, el.selectionStart ?? 0);
  }

  /**
   * Backspace and Delete against a separator would otherwise do nothing visible — the
   * comma is removed and immediately re-derived. Eat the digit beside it instead.
   */
  function onkeydown(event: KeyboardEvent) {
    const el = event.currentTarget as HTMLInputElement;
    const pos = el.selectionStart ?? 0;

    if (pos !== el.selectionEnd) return;

    if (event.key === 'Backspace' && el.value[pos - 1] === ',') {
      event.preventDefault();
      commitValue(el.value.slice(0, pos - 2) + el.value.slice(pos), pos - 2);
    } else if (event.key === 'Delete' && el.value[pos] === ',') {
      event.preventDefault();
      commitValue(el.value.slice(0, pos) + el.value.slice(pos + 2), pos);
    }
  }

  const fromPlayer = (source: DragSource) => source.inventory === InventoryType.PLAYER;

  /**
   * What a press acts on: the selected slot, read live rather than captured.
   *
   * Only the player's own inventory — Use, Give and Drop are all things you do to something you
   * are carrying, which is the same rule `fromPlayer` applies to the drag path.
   */
  const held = $derived.by<SlotWithItem | undefined>(() => {
    if (selection.inventory !== InventoryType.PLAYER || selection.slot === null) return undefined;

    const slot = inv.leftInventory.items[selection.slot - 1];
    return isSlotWithItem(slot) ? slot : undefined;
  });

  /** Every verb clears the selection: the thing it named has just moved, been used or gone. */
  function run(action: (item: SlotWithItem) => unknown) {
    if (!held) return;

    action(held);
    clearSelection();
  }
</script>

<div class="control">
  <input
    class="amount"
    type="text"
    inputmode="numeric"
    bind:this={input}
    {value}
    {oninput}
    {onkeydown}
    aria-label="Item amount"
  />

  <button
    class="verb"
    disabled={!held}
    onclick={() => run(onUse)}
    use:droppable={{ canDrop: fromPlayer, ondrop: (source) => onUse(source.item) }}
  >
    {locale.ui_use || 'Use'}
  </button>

  <button
    class="verb"
    disabled={!held}
    onclick={() => run(onGive)}
    use:droppable={{ canDrop: fromPlayer, ondrop: (source) => onGive(source.item) }}
  >
    {locale.ui_give || 'Give'}
  </button>

  <button
    class="verb"
    disabled={!held}
    onclick={() => run((item) => dropToGround(item.slot))}
    use:droppable={{ canDrop: fromPlayer, ondrop: (source) => dropToGround(source.item.slot) }}
  >
    {locale.ui_drop || 'Drop'}
  </button>

  <button class="verb" onclick={() => fetchNui('exit')}>{locale.ui_close || 'Close'}</button>
</div>

<style>
  .control {
    display: flex;
    flex-direction: column;
    /* Never the column that gives. With three panes flexbox would otherwise take this
       one down to half its width before touching anything else. */
    flex: none;
    gap: var(--space-2);
    width: 150px;
    padding-top: var(--space-8);
  }

  .amount {
    width: 100%;
    padding: var(--space-2) var(--space-2);
    background: var(--tint-sunken);
    border: 1px solid var(--color-border);
    /* Reserved at rest exactly as a list row reserves it, so focus does not move the box. */
    border-left: 2px solid transparent;
    border-radius: var(--radius-sm);
    color: var(--color-white);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    text-align: center;
    transition:
      background-color var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out);
  }

  /*
   * FOCUS IS A RAIL AND A WASH, the same two things a selected list row takes.
   *
   * It was an accent border plus a 3px `--ring-accent` glow ring -- a halo, and this one hung in
   * the gap between the two panes with the game moving behind it, where a soft ring is the least
   * legible shape available. The rail is one hard edge and the wash is 8%; both survive whatever
   * is behind them.
   */
  .amount:focus {
    background: var(--primary-glow);
    border-color: var(--primary-glow-border);
    border-left-color: var(--color-primary);
    outline: none;
  }

  /* The state that makes the press honest: with nothing selected there is nothing to act on, and
     saying so on the control is the difference between "disabled" and "broken". */
  .verb:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .verb {
    padding: var(--space-2) var(--space-3);
    background: var(--surface-panel);
    /*
     * The one place in this UI where a bare panel really does have the world behind it.
     * `.control` has no fill, and neither does Inventory's `.wrapper` above it, so the three
     * verbs sit in the gap between the two panes with nothing but moving geometry behind
     * them. What holds them apart from it is the plane's alpha, the border and `--ink-scrim`
     * behind the ink — the same as the hotbar, whose comment carries the reason there is no
     * blur to be had for any of this.
     */
    text-shadow: var(--ink-scrim);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-sm);
    color: var(--color-gray);
    font-size: var(--text-sm);
    letter-spacing: var(--tracking-label);
    font-family: var(--font-display);
    text-transform: uppercase;
    transition:
      background var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out);
  }

  /* `:not(:disabled)`, or a verb with nothing selected lights up under the pointer and then
     refuses the press -- which is the same lie the missing `onclick` was telling. */
  .verb:hover:not(:disabled) {
    border-color: var(--primary-glow-border);
    color: var(--color-white);
  }

  /*
   * Set by the droppable action at runtime, so :global keeps Svelte from pruning it.
   *
   * `data-dnd-ok` marks every target that would accept what is being dragged. Slots
   * ignore it — thirty empty squares lighting up at once is noise — but these two are
   * exactly the case it exists for: nothing about a button says "you can drop an item on
   * me", so a player who has not read the controls panel never discovers them.
   */
  .verb:global([data-dnd-ok]) {
    border-color: var(--primary-glow-border);
    color: var(--color-gray);
  }

  .verb:global([data-dnd-over]) {
    /* Tint over the button's surface, not in place of it — see tokens.css. */
    background: rgba(20, 46, 50, 0.931);  /* CEF 103 has no color-mix() -- see theme/base.css */
    background: color-mix(in srgb, var(--color-primary) 14%, var(--surface-panel));
    text-shadow: var(--ink-scrim);
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

</style>
