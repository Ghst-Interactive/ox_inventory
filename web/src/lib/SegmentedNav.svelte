<script lang="ts">
  import type { Snippet } from 'svelte';

  /**
   * The pill-in-a-pill tab control: a fully rounded track with a fully rounded chip sliding
   * between the options.
   *
   * ONE FILE WITH COPIES, held to byte identity by `Tools/checks/copies.py` for the reason every
   * shared component here is: a Svelte component cannot be imported across a NUI resource
   * boundary, and two panels disagreeing about where the chip is or what colour "you are here"
   * means is the loudest version of the inconsistency that list exists to catch.
   *
   * **WRITTEN IN `ox_lib`, WHICH IS WHERE IT HAS TO BE CHANGED.** That library is LGPL and this
   * template is GPL, so the copy flows one way only: `ox_lib -> everywhere`. Editing it here and
   * propagating outward would put GPL code into an LGPL fork, which is the one direction this
   * tree's licence rule closes. `KeyGlyph` and `Bar` are the same arrangement for the same
   * reason. See `Tools/README.md` on licensing.
   *
   * The one place the corner scale is deliberately not applied. Panels and rows went square in
   * the Solar Crown pass; controls did not, because the reference's own contrast between a 2px
   * slab and a 9999px pill is the look rather than an inconsistency. A square tab strip beside a
   * square panel is a spreadsheet.
   *
   * The active chip is WHITE, not the accent, and that is the reference's rule too: white means
   * "you are here", the accent means "this is interactive". A cyan chip would say the tab is a
   * button you have not pressed yet.
   */

  interface Option {
    value: string;
    label: string;
    /**
     * A count riding on the tab: unread messages, bills waiting on you.
     *
     * Added for `ghst_banking`, whose Requests tab is worth being a tab *because* it can say
     * somebody is waiting — a strip that could not carry that number would have been a strip it
     * kept its own copy of instead. Falsy values draw nothing, so a zero is absence rather than a
     * pip saying "none".
     *
     * The accent, never a warning colour: somebody asking you for money is not an error, and a
     * red pip on a bank panel reads as one.
     */
    badge?: number | string;
    /**
     * A leading glyph, rendered by the caller.
     *
     * **This is what thirteen hand-rolled tab strips had that this component did not.** Every one
     * of them was measured on 2026-09-04 and the difference was the same every time: an icon
     * beside the word. `ghst_customs` and `ghst_appearance` both recorded "icon-only strip" as a
     * reason they could not use this file, and both then wrote the strip again.
     *
     * A snippet rather than an icon name, because this file must not depend on an icon library —
     * `ox_lib`, the template and eighteen resources each resolve names through their own
     * `lib/icons.ts`, and a component that imported one could not be copied into the others.
     */
    glyph?: Snippet;
  }

  interface Props {
    options: Option[];
    value: string;
    onchange?: (value: string) => void;
    /** Accessible name for the group. Required — a tab strip with no name is a row of words. */
    label: string;
    /**
     * `track` (default) is the strip as it has always been: chips inside a sunken, bordered rail,
     * for a strip that sits **inside** a surface.
     *
     * `loose` drops the rail and spaces the chips out, for a strip that sits **on the scene** with
     * nothing behind it — `ghst_appearance`'s mode strip across the top of the shop, which is the
     * reference's own shape. A rail there would be a fifth surface floating over the game; without
     * one, the gaps between chips are the scene and the strip reads as chrome rather than a panel.
     *
     * A variant rather than a second component, deliberately. The two differ in chrome and in
     * nothing else — same roles, same keyboard, same selected state — and splitting one concept
     * across two files is exactly how `ChoiceRow` ended up with one adopter and forty-nine rivals.
     */
    variant?: 'track' | 'loose';
  }

  let { options, value, onchange, label, variant = 'track' }: Props = $props();
</script>

<div class="seg" class:loose={variant === 'loose'} role="tablist" aria-label={label}>
  {#each options as option (option.value)}
    <button
      type="button"
      role="tab"
      aria-selected={option.value === value}
      class:active={option.value === value}
      onclick={() => onchange?.(option.value)}
    >
      {#if option.glyph}<span class="glyph">{@render option.glyph()}</span>{/if}
      {option.label}
      {#if option.badge}<span class="badge">{option.badge}</span>{/if}
    </button>
  {/each}
</div>

<style>
  .seg {
    display: inline-flex;
    gap: calc(2 * var(--ui-px));
    padding: calc(3 * var(--ui-px));

    background: var(--surface-sunken);
    /* Nested inside whatever chrome hosts it; settles the scrim rather than inheriting. */
    text-shadow: none;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-full);
  }

  button {
    display: inline-flex;
    align-items: center;
    gap: calc(5 * var(--ui-px));
    padding: calc(5 * var(--ui-px)) calc(13 * var(--ui-px));

    font-family: var(--font-display);
    font-variation-settings: 'wdth' 112;
    font-size: var(--text-label);
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;

    color: var(--color-gray);
    background: transparent;
    border: 0;
    border-radius: var(--radius-full);
    cursor: pointer;

    transition:
      color var(--dur-fast) var(--ease-out),
      background-color var(--dur-fast) var(--ease-out);
  }

  /*
   * No rail, wider gaps, and each chip carries its own edge.
   *
   * A strip on the scene has nothing behind it, so the chips have to be legible on their own —
   * which is the opposite of the tracked variant, where the rail does that job and a border on
   * each chip would be a line inside a line.
   */
  .seg.loose {
    gap: var(--space-1);
    padding: 0;
    border: 0;
    border-radius: 0;
    background: none;
  }

  .seg.loose button {
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--surface-panel);
    padding: var(--space-2) var(--space-4);
    /* The chip carries the scrim, not the strip: in this variant each chip IS the surface, and a
       shadow declared on the transparent wrapper is credited to ink that has a plate under it. */
    text-shadow: var(--ink-scrim);
  }

  /*
   * The active chip's own fill, restated here, and it has to be.
   *
   * `button.active` below paints `--color-white` with `--color-on-accent` ink. That rule is
   * `(0,1,1)`; `.seg.loose button` above is `(0,2,1)` and was quietly winning the `background`
   * declaration -- so a selected loose chip kept `--surface-panel` and took the dark ink meant to
   * sit on white. Dark on dark. Only the border survived, which is why it still read as *chosen*
   * while being the least legible chip in the strip.
   *
   * Found 2026-09-04 from a screenshot of `ghst_appearance`'s mode strip, and it is the second
   * bug of the day that the Kit gallery could not have caught: nothing in the gallery was
   * clickable, so no loose chip had ever been selected by hand.
   */
  .seg.loose button.active {
    background: var(--color-white);
    border-color: var(--color-white);
    text-shadow: none;
  }

  /*
   * **`:not(.active)`, because the active chip is white and this ink is white.**
   *
   * The selected chip paints `--color-white` and inks itself for that plate. This rule then took
   * every button on hover -- including that one -- and set the ink to white as well, so pointing at
   * the tab you are already on made its label vanish into its own chip. Silent, momentary, and
   * invisible in a screenshot taken without a cursor in it.
   *
   * The hover *background* goes with it deliberately: an active chip already has a plate, and
   * `--tint-raised` over white is a grey smear rather than feedback. The loose variant's
   * `--layer-hover` wash below still applies, so pointing at the active chip is still acknowledged.
   *
   * Found 2026-09-08 in `ghst_appearance`'s frame bar, from a screenshot with the cursor resting on
   * `FULL`. It is the third bug in this file's short history to be a rule that did not exclude the
   * state it did not mean -- see `.seg.loose button.active` above for the first two.
   */
  button:hover:not(.active) {
    color: var(--color-white);
    background: var(--tint-raised);
  }

  .seg.loose button:hover {
    background-image: var(--layer-hover);
  }

  .glyph {
    display: grid;
    place-items: center;
    color: inherit;
  }

  button.active {
    color: var(--color-on-accent);
    background: var(--color-white);
  }

  .badge {
    display: grid;
    place-items: center;
    min-width: calc(15 * var(--ui-px));
    height: calc(15 * var(--ui-px));
    padding: 0 calc(4 * var(--ui-px));

    background: var(--color-primary);
    color: var(--color-on-accent);
    border-radius: var(--radius-full);

    font-variant-numeric: tabular-nums;
    font-size: var(--text-micro);
    letter-spacing: 0;
  }

  /* On the active chip the ground is already white, so the accent pip would sit on it as two
     bright shapes arguing. It inverts instead: the chip's own ink carries the count. */
  button.active .badge {
    background: var(--color-on-accent);
    color: var(--color-white);
  }

  button:focus-visible {
    outline: 2px solid var(--color-primary);
    outline-offset: 2px;
  }
</style>
