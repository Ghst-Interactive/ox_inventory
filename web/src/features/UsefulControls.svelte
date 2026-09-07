<script lang="ts">
  import { fade, scale } from 'svelte/transition';
  import { locale } from '../lib/state.svelte';
  import Icon from '../lib/Icon.svelte';
  import { X } from '../lib/icons';

  let { open = $bindable(false) }: { open?: boolean } = $props();

  /**
   * The controls cheat sheet. A plain modal — floating-ui's overlay, focus manager and
   * dismiss handling were doing nothing here that a scrim and an Escape key do not.
   */
  const controls = $derived([
    { keys: 'RMB', description: locale.ui_rmb },
    { keys: 'ALT + LMB', description: locale.ui_alt_lmb },
    { keys: 'CTRL + LMB', description: locale.ui_ctrl_lmb },
    { keys: 'SHIFT + Drag', description: locale.ui_shift_drag },
    { keys: 'ALT + Drag', description: locale.ui_alt_drag },
    { keys: 'CTRL + SHIFT + LMB', description: locale.ui_ctrl_shift_lmb },
    { keys: 'CTRL + C', description: locale.ui_ctrl_c },
  ]);

  function onkeydown(event: KeyboardEvent) {
    if (!open || event.key !== 'Escape') return;

    // Escape also closes the inventory itself; the dialog is on top, so it wins.
    event.stopPropagation();
    open = false;
  }
</script>

<svelte:window {onkeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="scrim" onclick={() => (open = false)} transition:fade={{ duration: 120 }}>
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="dialog"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
      onclick={(event) => event.stopPropagation()}
      transition:scale={{ duration: 150, start: 0.96 }}
    >
      <header>
        <p>{locale.ui_usefulcontrols || 'Useful controls'}</p>
        <button class="close" onclick={() => (open = false)} aria-label="Close">
          <Icon node={X} size="12px" />
        </button>
      </header>

      <dl>
        {#each controls as control (control.keys)}
          <div class="row">
            <dt><kbd>{control.keys}</kbd></dt>
            <dd>{control.description ?? ''}</dd>
          </div>
        {/each}
      </dl>
    </div>
  </div>
{/if}

<style>
  .scrim {
    position: fixed;
    inset: 0;
    z-index: 90;
    display: grid;
    place-items: center;
    background: var(--scrim);
  }

  /* The dialog's own padding is gone and `overflow: hidden` takes its place, so the rows below can
     be full-bleed slabs clipped to its corners rather than a column inset from an edge the dialog
     had already drawn. Each region carries its own padding now. */
  .dialog {
    width: 420px;
    max-width: calc(100vw - 32px);
    background: var(--surface-raised);
    text-shadow: none;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);
    box-shadow: inset 0 1px 0 var(--edge-highlight), var(--shadow-panel);
    overflow: hidden;
  }

  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--color-border);
  }

  /* The eyebrow. It was `--text-subheading` in white -- a sentence set large, which is how a web
     page titles a modal and not how anything else in this tree does it. Small, wide, tracked,
     uppercase and dim reads as a heading because of its treatment rather than its size. */
  header p {
    margin: 0;
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    font-family: var(--font-display);
    text-transform: uppercase;
    color: var(--color-dim);
  }

  .close {
    padding: var(--space-1-5);
    color: var(--color-dim);
    border-radius: var(--radius-sm);
  }

  .close:hover {
    color: var(--color-danger-text);
  }

  dl {
    display: flex;
    flex-direction: column;
    /* Clear of the dialog's bottom edge; the rows carry the rest of the inset themselves. */
    padding-bottom: var(--space-2);
  }

  /*
   * HAIRLINES, NOT A GUTTER. This is a table of seven bindings, and the gap between rows was
   * saying what a one-pixel rule says better -- the same change `ContextMenu` and `GivePicker`
   * took next door. `border-top` so the rule never lands under the last row.
   */
  .row {
    display: grid;
    grid-template-columns: 150px 1fr;
    gap: var(--space-3);
    align-items: center;
    padding: var(--space-2) var(--space-4);
    border-top: 1px solid var(--color-border);
  }

  /* Direct children of the <dl>; the header's bottom border separates the first one. */
  .row:first-child {
    border-top-color: transparent;
  }

  kbd {
    display: inline-block;
    padding: var(--space-0-5) var(--space-1-5);
    background: var(--tint-sunken);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-sm);
    color: var(--color-primary);
    font-family: var(--font-mono);
    font-size: var(--text-meta);
  }

  dd {
    color: var(--color-gray);
    font-size: var(--text-sm);
  }
</style>
