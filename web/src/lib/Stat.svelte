<script lang="ts">
  /**
   * A number that is the point of the row it is in.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * Trait 10 of `docs/ui-tdu.md`: *"large, tabular, technical face; the number is the hero of a
   * row"*, against *"numbers are body text"*. Fourteen resources draw one — a balance, a price, a
   * speed, a total — and every one of them re-decides the face, the size and whether the digits
   * are tabular.
   *
   * ## Tabular is the load-bearing part
   *
   * A total that changes as you shop, a speed that changes every frame, a fuel percentage counting
   * down: proportional digits make all three *jitter sideways* as the glyphs change width, and the
   * eye reads that as the whole panel twitching. `font-variant-numeric: tabular-nums` is why this
   * is a component rather than a pair of tokens somebody remembers to apply.
   *
   * ## What it does not do
   *
   * It does not format. `$1,200`, `18%` and `253 km/h` are the caller's — a component that took a
   * raw number and a unit would have to own currency, precision and locale, and this tree already
   * has `lib/format.ts` files that do. This takes the finished string.
   */
  interface Props {
    /** The number, already formatted. */
    value: string | number;
    /** The tracked caps label *under* it. Optional: a stat in a row that is already labelled. */
    label?: string;
    /** A trailing unit or qualifier, one step down — `km/h`, `+ tax`, `past hour`. */
    unit?: string;
    /**
     * How loud the number is. Three steps, and the middle one was missing.
     *
     * - `hero` (`--text-display`) — the one number a panel is *about*.
     * - `figure` (`--text-heading`) — a number that carries a row or a corner. Several may sit on
     *   one panel, and sometimes that is the design rather than a failure of it.
     * - `plain` (`--text-subheading`) — a number inside dense content.
     *
     * This shipped with two, on the argument that *"the whole point of the trait is that one
     * number on a screen is the hero and the rest are not, and a size prop would let two of them
     * be."* Measured across the tree on 2026-09-04, that is simply not what is there: **six**
     * display-face tabular numbers sit at `--text-heading` and **seven** at `--text-subheading`,
     * and the two-size ladder had no name for the larger of those.
     *
     * `ghst_shops` is the case that shows the argument was wrong rather than merely incomplete.
     * Its wallet and its tray total are deliberately the same size, because *"the panel's whole
     * argument is those two numbers against each other: what you are carrying, and what this comes
     * to."* That is two equal figures on purpose.
     *
     * Still named by role rather than by size, which is what keeps it from being a free number: a
     * caller picks what the figure *is*, and there is exactly one `hero`.
     */
    size?: 'hero' | 'figure' | 'plain';
    /** Colour, when the number carries a verdict — a refusal, a gain, something live. */
    tone?: 'default' | 'primary' | 'success' | 'danger' | 'warn';
    /**
     * Which edge the number and its label line up on.
     *
     * `end` is for a stat pinned to a right edge, where the label is usually wider than the
     * figure and a left-aligned number floats away from the edge it belongs to. Both of the
     * tree's header-right readouts want it — `ghst_skills`' average and `ghst_shops`' wallet,
     * which both wrote `text-align: right` — and a caller cannot supply it from outside, because
     * `.line` is a flex row and `text-align` does not reach a flex item's placement.
     */
    align?: 'start' | 'end';
  }

  let {
    value,
    label,
    unit,
    size = 'plain',
    tone = 'default',
    align = 'start',
  }: Props = $props();
</script>

<!--
  THE LABEL GOES UNDER THE NUMBER, which is the opposite of `Panel`'s eyebrow and is not an
  inconsistency. A panel's eyebrow is above its title because you orient before you read; a hero
  number is glanced at, and a caption over it makes the caption the first thing read, which is the
  one thing this component exists to prevent.

  Measured, not reasoned: both captioned heroes in the tree do it this way. `ghst_skills` --
  *"one number, large, with its name under it in the caps label"* -- and `ghst_shops`' wallet,
  which is a value with `Cash` beneath. This shipped with the label above and matched neither.

  AND THE OTHER SIDE IS A DIFFERENT OBJECT, WHICH IS THE BOUNDARY OF THIS COMPONENT. `StatTable`
  puts its labels above, and so does `ghst_banking`'s Fleeca card -- `BALANCE` over the figure,
  `CASH ON HAND` over the other one. Neither is wrong and neither should adopt this: a hero is
  GLANCED at, so a caption over it steals the glance; a set of RIVAL figures has to say which one
  you are reading before you read it, because knowing that is the whole point of there being two.
  A stat sheet is rivals by construction. A bank card carries two numbers a metre apart in
  meaning.

  So the rule is not "labels go under". It is: one number, caption under; several numbers you are
  choosing between, caption over -- and the second of those is `StatTable`, not this.
-->
<p class="stat {size} {tone} {align}">
  <span class="line">
    <span class="value">{value}</span>
    {#if unit}<span class="unit">{unit}</span>{/if}
  </span>

  {#if label}<span class="label">{label}</span>{/if}
</p>

<style>
  .stat {
    display: flex;
    flex-direction: column;
    gap: var(--space-0-5);
  }

  /* `align-items` on the block and `justify-content` on the line, because the two axes are
     different elements: the label and the value line are the column's items, and the value and
     its unit are the line's. Setting one without the other lines up the label and leaves the
     figure where it was. */
  .stat.end {
    align-items: flex-end;
  }

  .stat.end .line {
    justify-content: flex-end;
  }

  /* The eyebrow shape, under the number rather than over it — see the markup. */
  .label {
    color: var(--color-dim);
    font-family: var(--font-display);
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
  }

  .line {
    display: flex;
    align-items: baseline;
    gap: var(--space-1-5);
  }

  .value {
    font-family: var(--font-display);
    font-variant-numeric: tabular-nums;
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-extrabold);
    letter-spacing: var(--tracking-display);
    line-height: var(--leading-tight);
  }

  /*
   * `--text-display` (30px), NOT `--text-heading` (22px), which is what this shipped at and what
   * every hero in the tree disagreed with. Measured 2026-09-04 while adopting this in `ghst_fuel`:
   * the three hand-rolled heroes are `ghst_skills`' average, `ghst_crypto`' price and this pump's
   * headline, and all three are `--text-display`. `ghst_crypto/web/src/App.svelte` says it in as
   * many words -- *"set the way every hero in the tree is"* -- and `ghst_skills` argues the step:
   * *"a summary drawn at the same size as the six values it summarises is not a summary, it is a
   * seventh row."*
   *
   * The gallery could not have caught this. A hero shown beside no rivals is the right size by
   * definition; it took a call site with something to compete with.
   *
   * The one measured exception this recorded is now gone, and it went the way it should have: the
   * note said `ghst_crypto`'s phone screen steps down to `--text-heading` because `--text-display`
   * at seven figures wraps on a handset, *"and a third size here would undo the argument against a
   * free `size` -- so it is left hand-rolled until that resource's turn in the queue."* `figure`
   * arrived for `ghst_shops` before that turn came, and it is exactly the step the phone wanted.
   *
   * Worth noting which way round that happened. The exception was not accommodated; it was the
   * second piece of evidence for a size the ladder was missing, and the resource that needed it
   * found it on a different panel for a different reason.
   */
  .hero .value {
    color: var(--color-white);
    font-size: var(--text-display);
  }

  .figure .value {
    color: var(--color-white);
    font-size: var(--text-heading);
  }

  .plain .value {
    color: var(--color-white);
    font-size: var(--text-subheading);
  }

  /* Not on the display face and not tabular: a unit is a word, and setting it in the numeral face
     makes it read as part of the number. */
  .unit {
    color: var(--color-dim);
    font-size: var(--text-meta);
  }

  .primary .value {
    color: var(--color-primary);
  }

  .success .value {
    color: var(--color-success);
  }

  .danger .value {
    color: var(--color-danger-text);
  }

  .warn .value {
    color: var(--color-warn);
  }
</style>
