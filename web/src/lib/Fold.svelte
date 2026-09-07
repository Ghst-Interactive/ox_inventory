<script lang="ts">
  /**
   * A section that opens and closes: a heading you press, and whatever is under it.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * The smallest component in the kit and the one most often rewritten badly, because the parts
   * that matter are not the visible ones: `aria-expanded` on the *button* rather than the region,
   * a chevron that rotates rather than swapping glyph, and content that is genuinely removed from
   * the DOM rather than hidden.
   *
   * ## Removed, not hidden
   *
   * `{#if open}` rather than `display: none`, and it is not a micro-optimisation. A collapsed fold
   * holding a live control keeps that control focusable and keeps its effects running — a hidden
   * grid of two hundred garments still pays for its images, and a hidden slider still answers the
   * arrow keys of somebody who tabbed into it by accident. Removing it is also what makes reopening
   * a fold reset whatever transient state it held, which is nearly always what a player expects.
   *
   * The cost is that a fold is not the place for anything expensive to rebuild. That is the right
   * trade for a disclosure and the wrong one for a tab strip, which is why those are different
   * components.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    title: string;
    /** A short qualifier beside the title — which garment these colours belong to, a count. */
    note?: string;
    /** Bound, so a caller can open a fold from elsewhere and remember its state across a remount. */
    open?: boolean;
    /** The chevron. Passed in so this file needs no icon library — it is rotated, never swapped. */
    chevron?: Snippet;
    children: Snippet;
  }

  let { title, note, open = $bindable(true), chevron, children }: Props = $props();
</script>

<section class="fold">
  <button class="head" type="button" aria-expanded={open} onclick={() => (open = !open)}>
    <span class="title">{title}</span>
    {#if note}<span class="note">{note}</span>{/if}
    {#if chevron}
      <span class="chev" class:up={open}>{@render chevron()}</span>
    {/if}
  </button>

  {#if open}
    <div class="body">{@render children()}</div>
  {/if}
</section>

<style>
  .fold {
    display: flex;
    min-height: 0;
    flex-direction: column;
  }

  .head {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    color: var(--color-gray);
    font-family: var(--font-display);
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-align: left;
    text-transform: uppercase;
    transition: color var(--dur-fast) var(--ease-out);
  }

  .head:hover {
    color: var(--color-white);
  }

  .title {
    flex: none;
  }

  /* Pushed to the right and dimmed: it qualifies the title rather than continuing it, and at this
     size two pieces of caps text side by side read as one long label. */
  .note {
    flex: 1;
    overflow: hidden;
    color: var(--color-dim);
    font-family: var(--font-mono);
    font-size: var(--text-meta);
    letter-spacing: 0;
    text-align: right;
    text-overflow: ellipsis;
    text-transform: none;
    white-space: nowrap;
  }

  .chev {
    display: grid;
    flex: none;
    place-items: center;
    align-self: center;
    color: var(--color-dim);
    transition: rotate var(--dur-fast) var(--ease-out);
  }

  /* Rotated, never swapped for a different glyph. A chevron that turns says the same thing is
     still there and is about to move; two different glyphs read as two different controls. */
  .chev.up {
    rotate: 180deg;
  }

  .body {
    display: flex;
    min-height: 0;
    flex-direction: column;
    padding: 0 var(--space-3) var(--space-3);
  }
</style>
