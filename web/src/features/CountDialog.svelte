<script lang="ts">
  import type { Snippet } from 'svelte';
  import Shell from '../lib/Shell.svelte';
  import Panel from '../lib/Panel.svelte';
  import Button from '../lib/Button.svelte';
  import KeyHints from '../lib/KeyHints.svelte';
  import { locale } from '../lib/state.svelte';
  import CountControl from './CountControl.svelte';

  /**
   * THE FRAME GIVE, SPLIT AND DROP SHARE.
   *
   * The three ask the same question — how many, and then do it — and until the design walk they
   * asked it in three shapes: Split and Drop in a popover pinned to the pointer, Give in a dialog
   * of its own with a hand-rolled header and a list whose rows committed on click. The walk's row
   * for this resource settled it as one centred kit `Panel` per verb, so the frame is one file and
   * what differs is the eyebrow, the blurb, the body above the count and the payload the confirm
   * button sends. The design gallery drew the three in `screens/Inventory.svelte`, `modals` --
   * deleted 2026-09-08, `ghst_template` `dcebad1`.
   *
   * ## Why it is centred rather than at the pointer
   *
   * The popover's argument was that it lands on the slot you were aiming at. What it cost is that
   * the dialog was a different size and a different weight from every other surface in the tree,
   * and it was the only one of the three; a player who split, gave and dropped in one session met
   * three answers to one question. A centred panel is where every other confirm in the pass sits.
   *
   * ## `scrim="clear"`, not `scrim={false}`
   *
   * The mockup says `false`, because a mockup has no live inventory grid behind it. Here there is:
   * the veil is what stops the click that dismisses the dialog from landing on a slot and starting
   * another drag, which is the same reason the popover carried an invisible catcher of its own.
   * `clear` paints nothing and claims its pixels, so the walk's no-veil rule is kept exactly.
   */

  interface Props {
    /** The verb, as the panel's eyebrow — Give, Split, Drop. */
    eyebrow: string;
    /** The item being counted out. */
    title: string;
    /** One line saying where it goes. */
    blurb: string;
    /** The most this count may reach. */
    max: number;
    count: number;
    /** The whole of the confirm button — the verb folded into the figure, "Give 2 to Sofia". */
    confirm: string;
    /** A confirm that cannot run yet: Give with nobody chosen. Enter is refused too. */
    disabled?: boolean;
    onconfirm: () => void;
    oncancel: () => void;
    /** Anything above the count control. Give's list of people; the other two have none. */
    before?: Snippet;
  }

  let {
    eyebrow,
    title,
    blurb,
    max,
    count = $bindable(1),
    confirm,
    disabled = false,
    onconfirm,
    oncancel,
    before,
  }: Props = $props();

  function run() {
    if (disabled) return;
    onconfirm();
  }

  /**
   * Escape and Enter, taken here rather than through `Shell`'s `onescape`.
   *
   * Both are also inventory-level shortcuts — Escape closes the window, digits use a hot slot —
   * and this dialog is on top, so it takes them first and says so by stopping propagation, which
   * is what the popover did before it.
   */
  function onkeydown(event: KeyboardEvent) {
    event.stopPropagation();

    if (event.key === 'Escape') oncancel();
    else if (event.key === 'Enter') run();
  }
</script>

<svelte:window {onkeydown} />

<Shell scrim="clear" onscrim={oncancel}>
  {#snippet hints()}
    <!-- Bottom left, ambient, white type. It replaces the inventory's own `esc Close` for as long
         as a dialog is up — see Inventory.svelte — because two plates in one corner is two answers
         to the same key. -->
    <div class="plate">
      <KeyHints
        tone="ambient"
        layout="inline"
        hints={[
          { key: 'enter', does: locale.ui_confirm || 'Confirm' },
          { key: 'esc', does: locale.ui_cancel || 'Cancel' },
        ]}
      />
    </div>
  {/snippet}

  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="dialog"
    role="dialog"
    aria-modal="true"
    tabindex="-1"
    aria-label={eyebrow}
    onclick={(event) => event.stopPropagation()}
    oncontextmenu={(event) => event.preventDefault()}
  >
    <Panel {eyebrow} {title} {blurb}>
      <div class="body">
        {@render before?.()}
        <CountControl bind:value={count} {max} />
      </div>

      {#snippet footer()}
        <!-- ONE FILLED BUTTON, and it carries the figure. The walk's fold-in rule: the verb and
             the amount are one thing to read, not a verb strip and a second confirm. -->
        <div class="acts">
          <Button onclick={oncancel}>{locale.ui_cancel || 'Cancel'}</Button>
          <Button variant="filled" {disabled} onclick={run}>{confirm}</Button>
        </div>
      {/snippet}
    </Panel>
  </div>
</Shell>

<style>
  /* Above the two panes and the context menu, which is what opened it. */
  .dialog {
    position: relative;
    z-index: 80;
    display: flex;
    width: calc(320 * var(--ui-px));
    max-width: 100%;
    max-height: 100%;
    /* The dialog claims its own clicks; `Shell`'s frame deliberately does not. */
    pointer-events: auto;
  }

  /* `Panel`'s body is deliberately unpadded — a body with columns of its own would fight it —
     so the padding is the caller's, here as everywhere else in the pass. */
  .body {
    display: flex;
    min-height: 0;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    overflow-y: auto;
  }

  .acts {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }

  /*
   * The hint plate, and it paints NO ground — which is the inventory's own hint plate exactly, one
   * file away, and `KeyHints`' own rule: *"no surface, ever… a plate would make a hint cluster a
   * panel, and it is the least important thing on any screen it appears on."* The gallery mock
   * draws a filled plate here; this resource had already settled the other way for the plate in
   * the same corner, and two treatments of one corner is the thing to avoid.
   */
  .plate {
    pointer-events: auto;
  }
</style>
