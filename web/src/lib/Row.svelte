<script lang="ts">
  /**
   * One row of a list. The shape that actually recurs, derived from the forty-nine hand-rolled
   * ones rather than guessed at.
   *
   * ONE FILE WITH COPIES, like every shared component here: a Svelte component cannot be imported
   * across a NUI resource boundary — each `web/` is its own bundle — so a resource that draws a
   * list carries this file and `Tools/checks/copies.py` holds the copies to byte identity.
   *
   * **Authored in `ox_lib`, which is a licence decision and not a filing one.** ox_lib is LGPL and
   * every `ghst_*` is GPL, so a component written here reaches all of them plus `ox_inventory`;
   * one written in the GPL template can never come back the other way. `ChoiceRow` and
   * `StatTable` live in the template and are stuck at 21 of 22 resources for exactly that reason;
   * `Button` was too, until the dialogs needed it and it was rewritten here (2026-09-05).
   * `ox_target` is MIT and stays outside the kit — it has one button and no lists.
   *
   * ## Why this exists when `ChoiceRow` already does
   *
   * `ChoiceRow` argued in its own header against a generic row — *"a component with a hole in the
   * middle just moves the disagreement inside the hole"* — and that argument is right, and is why
   * there is exactly one slot here rather than a body. What it got wrong was the shape: it was a
   * bare `<button>` carrying a label and a count, and it had **two call sites in one resource
   * against forty-nine hand-rolled rivals**. That was not neglect, it was a structural miss.
   *
   * A real row in this tree is a primary action **with secondary controls sitting on top of it** —
   * `ghst_emotes` says it plainly: *"the whole row is the play button and the two controls sit on
   * top of it… a list of a thousand things where the click target is a 20px glyph is a list nobody
   * uses."* You cannot nest a `<button>` inside a `<button>`, so a bare-button component cannot
   * express that at all, and every list needing it had to start again from a `<div>`.
   *
   * So the recurring parts are named props with no hole in them — glyph, label, sub, meta — and
   * there is exactly **one** slot, `trailing`, for the case that made the hole necessary. A row
   * with no `trailing` renders as a plain `<button>` and is structurally what `ChoiceRow` was.
   *
   * `ChoiceRow` is **retired**, on 2026-09-04, by the second pass as promised — not by this file,
   * so no resource changed underneath itself. Its two call sites were both in `ghst_garages` and
   * both moved by renaming `count` to `meta`, which is the whole of the difference for a row with
   * no `trailing`. See `docs/ui-tdu.md` §6.
   *
   * SIZED FROM THE THEME. `--row-text` and the two paddings are tokens because this has to work in
   * a menu at interface scale *and* on a world board read from seven metres, where `ghst_garages`
   * raises them past its legibility floor.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    label: string;
    /** A second line under the label. Absent is the common case and draws nothing. */
    sub?: string;
    /**
     * The number or short string on the right — a count, a price, a key.
     *
     * Named `meta` rather than `count` because a third of the rows measured carry a price or a
     * keybind rather than a tally, and a prop called `count` holding "$1,200" is a name that lies
     * at every call site.
     */
    meta?: number | string;
    /** A leading glyph. Pass the rendered icon, so this file needs no icon library of its own. */
    glyph?: Snippet;
    /**
     * Secondary controls, pinned right and drawn *over* the row's own hit area.
     *
     * The one slot, and the reason this component exists. Its presence changes the markup: with it
     * the row is a `<div>` carrying an absolutely-filled hit button, without it the row simply is
     * the button. Two shapes rather than always the heavier one, because a list of a thousand
     * emotes should not carry a wrapper element per row for a feature it does not use.
     */
    trailing?: Snippet;
    selected?: boolean;
    disabled?: boolean;
    onclick?: () => void;
  }

  let {
    label,
    sub,
    meta,
    glyph,
    trailing,
    selected = false,
    disabled = false,
    onclick,
  }: Props = $props();
</script>

{#snippet body()}
  {#if glyph}
    <span class="glyph">{@render glyph()}</span>
  {/if}

  <span class="text">
    <span class="label">{label}</span>
    {#if sub}<span class="sub">{sub}</span>{/if}
  </span>

  {#if meta !== undefined}
    <span class="meta">{meta}</span>
  {/if}
{/snippet}

{#if trailing}
  <!-- The heavier shape. `aria-pressed` rides the hit button rather than the wrapper, because the
       wrapper is not the control — it is a region containing two of them. -->
  <div class="row" class:on={selected} class:disabled>
    <button class="hit" type="button" {disabled} aria-pressed={selected} {onclick}>
      {@render body()}
    </button>

    <span class="trailing">{@render trailing()}</span>
  </div>
{:else}
  <button
    class="row hit-only"
    class:on={selected}
    type="button"
    {disabled}
    aria-pressed={selected}
    {onclick}
  >
    {@render body()}
  </button>
{/if}

<style>
  /*
   * A FULL-BLEED SLAB WITH A HAIRLINE ABOVE IT, not a card in a gutter.
   *
   * The container carries the surface, the radius and the clip; a row carries none of them. That
   * is the honest structure as well as the reference's: the plane belongs to the list, and a row
   * is a region of it.
   *
   * `border-top` rather than `border-bottom`, so the rule falls BETWEEN rows and never under the
   * last one — a list with a line along its bottom edge inside a bordered container draws two
   * parallel hairlines a pixel apart.
   */
  .row {
    position: relative;
    display: flex;
    width: 100%;
    align-items: center;
    border-top: 1px solid var(--color-border);
    /* Reserved at rest, so taking the rail does not shift the row's own label sideways —
       `ChoiceRow` established this and it is the kind of thing that is invisible until a whole
       list nudges on click. */
    border-left: 2px solid transparent;
    color: var(--color-gray);
    text-align: left;
    transition:
      color var(--dur-fast) var(--ease-out),
      border-left-color var(--dur-fast) var(--ease-out),
      background-color var(--dur-fast) var(--ease-out);
  }

  .row:first-child {
    border-top: 0;
  }

  /* The padding is the hit button's, not the row's, so the whole slab is clickable in the heavy
     shape rather than only the text inside it. */
  .hit,
  .hit-only {
    display: flex;
    min-width: 0;
    flex: 1;
    align-items: center;
    gap: var(--space-3);
    padding: var(--row-pad-y) var(--row-pad-x);
    color: inherit;
    text-align: left;
  }

  .row:hover:not(.disabled),
  .hit-only:hover:not(:disabled) {
    background-image: var(--layer-hover);
    color: var(--color-white);
  }

  /*
   * **Exactly `ChoiceRow`'s selected state, deliberately.** An accent rail on the leading edge over
   * a wash of the accent — trait 6's "selection as an accent outline", as this tree already draws
   * it.
   *
   * It would have been easy to reach for an inset ring here instead, and that would have been the
   * wrong kind of improvement: `ChoiceRow` is retired by the second pass rather than by this file,
   * so for the length of that pass both are on screen in different resources, and two rows that do
   * the same job must not disagree about what *chosen* looks like.
   *
   * `background-image` rather than `background-color` for the hover above, for the reason
   * `ChoiceRow` records: `.on` sets a background and is declared after it, so a colour-vs-colour
   * fight means hovering an already-chosen row does nothing — the one row a player is most likely
   * to point at is the one that stops responding.
   */
  .row.on,
  .hit-only.on {
    border-left-color: var(--color-primary);
    background-color: var(--primary-glow);
    color: var(--color-white);
  }

  .row.disabled,
  .hit-only:disabled {
    color: var(--color-dim);
    cursor: not-allowed;
  }

  .glyph {
    display: grid;
    flex: none;
    place-items: center;
    color: var(--color-dim);
  }

  .text {
    display: flex;
    min-width: 0;
    flex: 1;
    flex-direction: column;
  }

  .label {
    overflow: hidden;
    font-size: var(--row-text);
    font-weight: var(--font-weight-semibold);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Dim and one step down. A sub-label competing with its own label is two labels. */
  .sub {
    overflow: hidden;
    color: var(--color-dim);
    font-size: var(--text-meta);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /*
   * Tabular, and on the display face. This is the number of the row — a count, a price, a key —
   * and trait 10 of the reference is that a number is the hero rather than body text. Tabular
   * because a column of prices that jitters as digits change is the one thing a list of numbers
   * must not do.
   */
  .meta {
    flex: none;
    color: var(--color-dim);
    font-family: var(--font-display);
    font-size: var(--text-meta);
    font-variant-numeric: tabular-nums;
    font-variation-settings: 'wdth' 112;
  }

  .trailing {
    display: flex;
    flex: none;
    align-items: center;
    gap: var(--space-1);
    padding-right: var(--row-pad-x);
  }
</style>
