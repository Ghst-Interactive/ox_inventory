<script lang="ts">
  import { onDestroy, untrack } from 'svelte';
  import { fade } from 'svelte/transition';
  import { fetchNui, onNuiEvent } from '../lib/nui';
  import { drag, endDrag } from '../lib/dnd.svelte';
  import {
    clearContainer,
    inv,
    refreshSlots,
    setAdditionalMetadata,
    paneById,
    setupContainer,
    setupInventory,
    type ItemsPayload,
    type RefreshPayload,
  } from '../lib/inventory.svelte';
  import {
    closeContextMenu,
    closeGivePicker,
    closeCountPrompt,
    closePanels,
    closeTooltip,
    closeWeaponPanel,
    countPrompt,
    givePicker,
    panels,
    ui,
    weaponPanel,
  } from '../lib/ui.svelte';
  import { onUse } from '../lib/actions';
  import { play } from '../lib/audio';
  import { isSlotWithItem } from '../lib/helpers';
  import type { Inventory } from '../typings';
  import AttachmentPanel from './AttachmentPanel.svelte';
  import ContextMenu from './ContextMenu.svelte';
  import GivePicker from './GivePicker.svelte';
  import InventoryControl from './InventoryControl.svelte';
  import InventoryGrid from './InventoryGrid.svelte';
  import CountPrompt from './CountPrompt.svelte';
  import Tooltip from './Tooltip.svelte';
  import KeyHints from '../lib/KeyHints.svelte';
  import { locale } from '../lib/state.svelte';

  /**
   * The two panes and the messages that drive them.
   *
   * Phase 2 owns setupInventory, refreshSlots and visibility. The centre column
   * (amount box, Use/Give/Close), the hotbar, tooltips and the context menu are phase 3.
   */

  const offVisible = onNuiEvent<boolean>(
    'setInventoryVisible',
    (state) => (ui.inventoryOpen = state),
  );

  /**
   * Sound the inventory opening and closing.
   *
   * An effect on the shared flag rather than a call inside each of the four places that
   * set it — setInventoryVisible, setupInventory, closeInventory and the Escape handler
   * all change the same thing, and three of them would have been easy to miss. The first
   * run is skipped so a page load is not announced.
   */
  let sounded = false;

  $effect(() => {
    const open = ui.inventoryOpen;

    /**
     * `play` is called untracked, and that is not a precaution.
     *
     * It reads the shared `uiVolume` preference to decide whether to make a sound at all, so calling it
     * inside the effect body makes the volume a dependency of *this* effect — and
     * dragging the volume slider then replays the open sound on every step. The harness
     * caught it: an open blip appeared in a window where the inventory had not opened.
     * Only the visibility flag belongs in the dependency set.
     */
    untrack(() => {
      if (sounded) play(open ? 'open' : 'close');
      sounded = true;
    });
  });

  /** Everything that has to stop when the inventory goes away. */
  function dismissAll() {
    // A drag surviving the inventory closing would drop into a pane that is no longer
    // on screen. React reached for manager.dispatch({type:'dnd-core/END_DRAG'}) here.
    endDrag();

    // The bag pane's lifetime is the window's: client.lua forgets `currentContainer` in
    // closeInventory and the server forgets `containerSlot`, so a pane kept past this
    // point is one nothing else believes in. See clearContainer for what that cost.
    clearContainer();
    closeTooltip();
    closeContextMenu();
    closeCountPrompt();
    closeWeaponPanel();
    closeGivePicker();

    // The controls sheet and the settings, which used to be `InventoryGrid`'s own state and so
    // outlived the window that raised them — reopening the bag found one still up.
    closePanels();
  }

  const offClose = onNuiEvent('closeInventory', () => {
    ui.inventoryOpen = false;
    dismissAll();
  });

  const offSetup = onNuiEvent<{ leftInventory?: Inventory; rightInventory?: Inventory }>(
    'setupInventory',
    (data) => {
      setupInventory(data);
      ui.inventoryOpen = true;
    },
  );

  /**
   * One listener, not one per slot.
   *
   * Upstream subscribed inside InventorySlot, so all thirty-plus visible slots scanned
   * every payload looking for themselves. The only reason any of them cared was to
   * cancel a drag whose source had just been rewritten by the server — at which point
   * the item being held may no longer exist, and completing the drop would act on a
   * stale slot.
   */
  const offRefresh = onNuiEvent<RefreshPayload>('refreshSlots', (data) => {
    refreshSlots(data);

    if (!drag.source || !data.items) return;

    const list: ItemsPayload[] = Array.isArray(data.items) ? data.items : [data.items];
    const held = drag.source;

    const rewritten = list.some((entry) => {
      if (!entry?.item) return false;

      // Resolved by id, the way the store's own refreshSlots does it two files away. Reading
      // "not player" as "the right pane" predates the bag pane, so a server rewrite of the slot
      // being dragged out of a *bag* never matched — and the drag went on to complete against a
      // slot whose contents had already changed underneath it.
      const pane = paneById(entry.inventory);

      return pane !== null && entry.item.slot === held.item.slot && pane.type === held.inventory;
    });

    if (rewritten) endDrag();
  });

  const offMetadata = onNuiEvent<Array<{ metadata: string; value: string }>>(
    'displayMetadata',
    setAdditionalMetadata,
  );

  // `false` rather than null on the wire: Lua cannot put a nil in a table and have it
  // survive the trip, so empty-handed is sent as false and normalised here.
  const offContainer = onNuiEvent<Inventory | false>('setupContainer', setupContainer);

  const offEquipped = onNuiEvent<number | false>(
    'setEquipped',
    (slot) => (ui.equippedSlot = slot === false ? null : slot),
  );

  /**
   * ONE ESCAPE, ONE THING.
   *
   * Every dialog in this resource takes Escape on **keydown** and this window takes it on
   * **keyup**, so a single press did both: the attachments screen closed, and a few milliseconds
   * later the window it had just returned to closed underneath it. `stopPropagation` in the dialog
   * cannot reach that — it is a different event — and the dialogs' own comments claiming "this is
   * on top, so it wins" were true only of the keydown half.
   *
   * It was worse than a stray close. The attachments screen borrows the screen blur while it is
   * up, so the two closes racing left a `TriggerScreenblurFadeIn` and a `TriggerScreenblurFadeOut`
   * on the same frame, and the blur stayed on an empty screen for the rest of the session.
   *
   * So the press is latched where the ambiguity is, rather than in each of the four dialogs: if a
   * dialog was up when the key went **down**, the matching **up** is spent. `dialogUp` is read at
   * keydown, which is before any dialog has had a chance to close — this handler is the parent's
   * and Svelte attaches it first.
   */
  let escapeSpent = false;

  function onKeyUp(event: KeyboardEvent) {
    if (event.key === 'Shift') inv.shiftPressed = false;

    if (event.code !== 'Escape') return;

    if (escapeSpent) {
      escapeSpent = false;
      return;
    }

    ui.inventoryOpen = false;
    dismissAll();
    fetchNui('exit');
  }

  /**
   * True while the player is typing into something — the pane search, today.
   *
   * Without this, typing "1" into a search field would also use whatever is in the first
   * hot slot, which for a stack of bandages is a wasted bandage and for a weapon is worse.
   */
  const typing = () => {
    const el = document.activeElement;
    return (
      el instanceof HTMLInputElement ||
      el instanceof HTMLTextAreaElement ||
      (el instanceof HTMLElement && el.isContentEditable)
    );
  };

  /**
   * Telling Lua that a field has the keyboard, so the game can stop reading it.
   *
   * `client.lua`'s `setTyping` is the other half and carries the reasoning: the window keeps the
   * game reading input the whole time it is open, so without this a `w` in the search box is also
   * a step forward, and an `m` is the phone opening on top of the inventory. The second one is not
   * something NUI focus can fix -- the engine dispatches a keybind whoever owns the keyboard --
   * which is why the answer has to be *declared* from here.
   *
   * **One pair of window listeners, not a flag on every field.** `focusin` and `focusout` bubble
   * to the window, so this covers the pane search, the count prompt and the give picker's amount
   * box without any of them knowing about it -- and covers whatever gets added next.
   *
   * **The way out is read a task later.** `focusout` fires *before* the next element takes focus,
   * so reading the active element during it reports "nobody is typing" for every Tab or click
   * between two fields -- and each of those false clears hands the game a frame of keyboard input
   * in the middle of a sentence. Deferring lets focus land first; a real blur still resolves to
   * nothing focused.
   *
   * Sent on every change rather than only on transitions, deliberately: this page cannot know when
   * Lua last cleared the hold on its own, and closing the window with the caret in the search box
   * is exactly that -- an element that is removed fires no blur, so Lua clears and the page never
   * hears. A mirror kept here would be stale from that moment on, and every keystroke after it a
   * hold nobody is told about. `setTyping` de-duplicates, because it is the side that also clears.
   */
  function announceTyping() {
    fetchNui('input', { typing: typing() });
  }

  const onFocusOut = () => setTimeout(announceTyping);

  /**
   * Slots 1-5 are keybound out in the world, but not in here — so using a hot slot meant
   * closing the inventory first, which is the one moment you can see what is in them.
   */
  function useHotslot(index: number) {
    const slot = inv.leftInventory.items[index - 1];

    if (!slot || !isSlotWithItem(slot)) return;

    closeTooltip();
    closeContextMenu();
    onUse(slot);
  }

  // Shift halves a stack on drop. Tracked globally because the key may be pressed
  // before the drag starts and released after it ends.
  function onKeyDown(event: KeyboardEvent) {
    if (event.key === 'Shift') inv.shiftPressed = true;

    // Before every early return below: whether this press belongs to a dialog is not a question
    // about drags, typing or modifiers. See `onKeyUp`.
    if (event.code === 'Escape' && dialogUp) escapeSpent = true;

    if (drag.source || typing() || event.ctrlKey || event.altKey || event.metaKey) return;

    // event.code, not event.key: the top-row digits report the same code on every layout,
    // where key would be an umlaut on some of them.
    const match = /^Digit([1-5])$/.exec(event.code);

    if (match) {
      event.preventDefault();
      useHotslot(Number(match[1]));
    }
  }

  /**
   * WHICH DIALOGS THE WINDOW HAS TO KNOW ABOUT, AND THE TWO THINGS IT USES THAT FOR.
   *
   * **The hint plate.** A dialog brings its own, in the same corner, and Escape means something
   * else while one is up. Two plates saying two things about one key is the reading the walk's
   * "minimal, usually only esc" rule exists to prevent, so this one stands down. The controls
   * sheet and the settings bring *no* plate, and the corner going empty is still right: while
   * either is up, Escape closes the dialog and not the window, so a plate reading "esc Close"
   * would be describing a key it no longer owns. Both carry a close button and a scrim.
   *
   * **The Escape latch**, which is why this list has to be complete — see `onKeyUp`. A dialog it
   * cannot see is a dialog whose Escape takes the inventory down with it, and that is exactly what
   * `panels.help` and `panels.settings` did until they moved out of `InventoryGrid` and into the
   * store on 2026-09-08.
   */
  const dialogUp = $derived(
    countPrompt.open ||
      givePicker.open ||
      weaponPanel.slot !== null ||
      panels.help ||
      panels.settings,
  );

  onDestroy(() => {
    offVisible();
    offClose();
    offSetup();
    offRefresh();
    offMetadata();
    offContainer();
    offEquipped();
  });
</script>

<svelte:window
  onkeyup={onKeyUp}
  onkeydown={onKeyDown}
  onfocusin={announceTyping}
  onfocusout={onFocusOut}
/>

{#if ui.inventoryOpen}
  <!-- The bag hangs under the player's own inventory rather than beside it: it is part of
       you, so it stays on your side of the control column, and stacking keeps the row to
       the two columns players already read left-to-right however many bags are open. -->
  <div
    class="wrapper"
    class:stacked={!!inv.containerInventory}
    class:away={weaponPanel.slot !== null}
    transition:fade={{ duration: 150 }}
  >
    <div class="column">
      <InventoryGrid inventory={inv.leftInventory} />
      {#if inv.containerInventory}
        <InventoryGrid inventory={inv.containerInventory} container />
      {/if}
    </div>
    <InventoryControl />
    <InventoryGrid inventory={inv.rightInventory} />
  </div>

  <!-- Bottom-left, minimal, ambient — the one hint plate every screen in the walk carries.
       Nothing here needs the tab/space/lmb/rmb list the gallery mock sketched: those are
       drag gestures a player discovers by dragging, and Escape is the one thing that has
       no other affordance on screen. -->
  {#if !dialogUp}
    <div class="hint-plate">
      <KeyHints tone="ambient" hints={[{ key: 'esc', does: locale.ui_close || 'Close' }]} />
    </div>
  {/if}

  <!-- Both are fixed-position and viewport-clamped, so they sit outside the wrapper
       rather than inside a pane that would clip them. -->
  <Tooltip />
  <ContextMenu />
  <CountPrompt />
  <AttachmentPanel />
  <GivePicker />
{/if}

<style>
  /*
   * Fixed to the viewport corner, same edge the tree's other ambient plates hold — never inside
   * `.wrapper`, whose padding answers the dev drawer rather than the screen edge.
   *
   * THE SECOND CLAUSE WAS TRUE AND THE FIRST WAS NOT, until 2026-09-08. This held `--space-4`,
   * which is 16px on `--ui-px`; the plates it names — `ox_lib`'s textUI and hint cluster,
   * `ghst_multichar`'s — hold `--edge-x` / `--edge-y`, which are a proportion of the DISPLAY and
   * deliberately not of the interface size. So this one sat four pixels in from the rest at scale
   * 1 and walked further out every time a player turned the UI up, which is the failure the token
   * exists to prevent: an inset from a physical screen edge must not move when the type does.
   */
  .hint-plate {
    position: fixed;
    left: var(--edge-x);
    bottom: var(--edge-y);
    z-index: 60;
  }

  /*
   * THE PANES STEP ASIDE FOR THE ATTACHMENTS SCREEN.
   *
   * That screen is the one surface in this resource whose subject is *behind* the page — a real
   * weapon object the client puts in the frame — and it wants the viewport, both for the room and
   * because Lua solves the camera distance from the size of the rectangle the page leaves open.
   * See the header of `AttachmentPanel.svelte`.
   *
   * Hidden rather than unmounted, and `display: none` rather than an `{#if}` around the panes for
   * exactly that reason: the grids keep their component state, so a bag scrolled halfway down and
   * a search box with a word in it are still that way when the player comes back from fitting a
   * scope. `visibility` would have kept the layout, and the panes would go on claiming their
   * clicks through a screen that is meant to be draggable everywhere.
   */
  .wrapper.away {
    display: none;
  }

  /*
   * Centred with flexbox rather than the usual top/left 50% plus a translate.
   *
   * The transform is not merely a different way to write this: a transformed element
   * becomes the containing block for any `position: fixed` descendant, so anything
   * inside that expected to cover the viewport instead covers this wrapper. That is
   * what happened to the controls dialog's scrim, which is rendered from
   * InventoryControl and so sits inside here — it darkened the two panes and nothing
   * else.
   *
   * Filling the viewport and centring the contents avoids the transform entirely, and
   * keeps it avoided for anything added inside later.
   */
  .wrapper {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-5);

    /* Centres within the space beside the dev drawer. 0 everywhere else — see app.css. */
    padding-left: var(--dev-shift);

    /* A stacked column is sized to fit whatever is left of the viewport, and without this
       "whatever is left" is the whole of it — panes flush against the top and bottom
       edges of the screen. This is the margin they keep. */
    padding-block: var(--space-4);
  }

  /*
   * The player's own column: their inventory, and under it the bag they have open.
   *
   * Centred with the other two rather than top-aligned, so the whole assembly stays
   * optically centred when a bag opens. What moves is this column alone — the control
   * column and the pane opposite are untouched, because each flex item is centred on its
   * own height.
   */
  .column {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);

    /*
     * THE COLUMN NEVER OUTGROWS THE SCREEN. Its two panes are otherwise both fixed
     * heights, and flexbox answers a column that does not fit by hanging it off both
     * ends — the player's first row above the top of the screen and the bag's last below
     * the bottom, on a 1080p client with a twenty-slot bag.
     *
     * So the bag gives way instead: this bounds the column, the pane below is the only
     * one allowed to shrink, and its grid scrolls to whatever rows are left. Every
     * viewport and every combination of headers, search fields and chips is then handled
     * by the same rule, without a table of heights to keep true.
     */
    max-height: 100%;
    min-height: 0;
  }

  /* The player's own pane keeps its five rows whatever happens. Addressed by position
     rather than :first-child, which would also match it when it is the only pane here and
     hand it the shrinking rule below. `.w-bag` is InventoryGrid's own root now that it
     wraps a kit `Panel` rather than a hand-rolled `.pane` section. */
  .column > :global(.w-bag:nth-child(1)) {
    flex: none;
  }

  /* The bag, second and last, is the one that gives way — see .column. */
  .column > :global(.w-bag:nth-child(2)) {
    flex: 0 1 auto;
    min-height: 0;
  }

  /*
   * A stacked column is taller than a single pane, so the slots give up a tenth of their
   * size to buy the room back. Measured, not guessed: a fifteenth is what a twenty-slot
   * bag needs to show all four of its rows beside a forty-slot inventory at 1080p, which
   * is the common client. Below that .column's rule takes over and the bag scrolls.
   *
   * Done by declaring --slot-size here rather than by setting some factor that :root's
   * declaration reads: a custom property is substituted where it is *declared*, so a
   * factor set on this element would never reach a --slot-size declared on :root. Hence
   * :root splits the size into a base and a scalar for this to re-derive.
   *
   * Not a transform, either. A transformed element becomes the containing block for its
   * `position: fixed` descendants, and the settings and controls dialogs are rendered
   * from InventoryControl, which is inside here — see the note on .wrapper above.
   */
  .wrapper.stacked {
    --slot-size: calc(var(--slot-base) * var(--slot-scale) * 0.85);
  }

</style>
