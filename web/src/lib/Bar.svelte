<script lang="ts">
  /**
   * The inline bar: hatched for a continuous value, notched for a counted one.
   *
   * ONE COMPONENT, and the props are what choose between the two renderings — pass `value` for
   * a fraction, or `done`/`total` for a count. This started as two components on the argument
   * that picking between them is a statement about the data and a `variant` prop would let a
   * call site avoid making it. That argument survives; the second component did not. The prop
   * *shape* already forces the statement, because you cannot hand this a fraction and get
   * notches, and two files meant two places for the geometry to drift.
   *
   * Why the distinction matters at all: a hatch reads as *accumulating* — experience, money,
   * distance. Notches read as *counted* — three daily challenges, eight season weeks. Drawing a
   * counted value as a continuous bar throws away the thing the player actually needs, which is
   * how many are left.
   *
   * The hatch geometry is `--hatch-*` in the theme, shared with
   * `features/progress/Progressbar.svelte`. Those two are different mechanisms — one is a timed
   * action animated by CSS, this is a value — but they are the same object to a player, and
   * they had already drifted to 45px against 10px with the gradient typed out twice.
   */

  interface Props {
    /** Continuous: 0–1. Clamped, so a stale total cannot paint past the end. */
    value?: number;
    /** Counted: pass both. Takes precedence over `value` if somebody passes everything. */
    done?: number;
    total?: number;
    /**
     * `action` is the moving one, and the distinction is the palette's own: `primary` is a value
     * at rest, `action` is THIS WIDGET reacting right now, `live` is an event in the world. A bar
     * being driven by something happening — a tank filling, a download — is `action`; a bar
     * reporting a rank the player already has is `primary`.
     *
     * `success` / `warn` / `danger` are the other axis: the value carries a **verdict**, and the
     * three of them are a scale rather than three separate claims. `ghst_garages`' condition bars
     * are the case — good, fair, poor for a car's body, engine and battery — and `Stat` already
     * carries the same three for the same reason. A bar with no verdict to give is `primary`;
     * reaching for green because a number is high is how green stops meaning anything.
     */
    tone?: 'primary' | 'action' | 'live' | 'success' | 'warn' | 'danger';
    /**
     * Over the moving game rather than in a panel: the label and readout go white, because the
     * grey tiers are for a panel's plane and vanish over a noon sky. The fuel pump and the timed
     * progress bar are ambient; a garage's condition bars are not.
     */
    ambient?: boolean;
    /**
     * A line across the track at 0–1: where this run stops, a threshold, a target. Drawn in the
     * *idle* accent whatever the fill's tone is, because it is a statement about the future and
     * the fill is a statement about now.
     */
    marker?: number;
    /**
     * Milliseconds between value updates, for a bar driven by a CLOCK rather than by an event.
     *
     * The default transition is an ease over `--dur-base`, which is right for a value that jumps
     * when something happens. A bar that is fed a new number four times a second has to cross
     * exactly one tick, linearly, or it visibly steps — and no literal can be right for both a
     * 250ms refuel and a 400ms siphon, which is why this is a number and not a token.
     */
    tick?: number;
    label?: string;
    /** Right-hand readout. Defaults to `done / total` when counting. */
    readout?: string;
  }

  let {
    value,
    done,
    total,
    tone = 'primary',
    ambient = false,
    marker,
    tick,
    label,
    readout,
  }: Props = $props();

  const counted = $derived(done !== undefined && total !== undefined);

  /**
   * Above about twenty cells a notch is thinner than the gap beside it and the row stops reading
   * as countable, which is the only reason to draw notches at all. Past that it degrades to a
   * hard-stopped fill — still not a hatch, because the value is still counted.
   */
  const CAP = 20;

  const safeTotal = $derived(Math.max(0, Math.floor(total ?? 0)));
  const safeDone = $derived(Math.max(0, Math.min(safeTotal, Math.floor(done ?? 0))));
  const countable = $derived(counted && safeTotal > 0 && safeTotal <= CAP);

  const pct = $derived(
    counted
      ? safeTotal
        ? (safeDone / safeTotal) * 100
        : 0
      : Math.max(0, Math.min(1, value ?? 0)) * 100,
  );

  const text = $derived(readout ?? (counted ? `${safeDone} / ${safeTotal}` : undefined));

  /** Clamped like the value: a marker past the end would sit on the border and read as a bug. */
  const markAt = $derived(marker === undefined ? undefined : Math.max(0, Math.min(1, marker)) * 100);
</script>

<div class="bar-block" class:ambient>
  {#if label || text}
    <div class="top">
      {#if label}<span class="label">{label}</span>{/if}
      {#if text}<span class="readout">{text}</span>{/if}
    </div>
  {/if}

  <div
    class="track {tone}"
    class:notched={countable}
    role="progressbar"
    aria-valuenow={counted ? safeDone : Math.round(pct)}
    aria-valuemin="0"
    aria-valuemax={counted ? safeTotal : 100}
    aria-label={label}
  >
    {#if countable}
      {#each { length: safeTotal } as _, i}
        <i class="cell" class:on={i < safeDone}></i>
      {/each}
    {:else}
      <!--
        WIDTH, NOT `scaleX`, AND THE HATCH IS WHY.

        The tree's motion convention is to animate `transform` — off the layout path, composited.
        It cannot be followed here: the hatch is a `repeating-linear-gradient` in *pixels*, so it
        is width-independent under a width change and stretches under a scale. A bar at 20% would
        draw 3px stripes as wedges. Scaling the background back to compensate is arithmetic that
        blows up as the value approaches zero.

        The cost is honest and small: this element is absolutely positioned inside a clipped
        track, so a width change lays out one out-of-flow box and moves nothing else.
      -->
      <div
        class="fill"
        class:solid={counted}
        style="width: {pct}%{tick === undefined
          ? ''
          : `; --bar-dur: ${tick}ms; --bar-ease: linear`}"
      ></div>
    {/if}

    {#if markAt !== undefined && !countable}
      <div class="marker" style="left: {markAt}%"></div>
    {/if}
  </div>
</div>

<style>
  .bar-block {
    display: grid;
    gap: var(--space-1);
  }

  .top {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .label {
    font-family: var(--font-display);
    font-variation-settings: 'wdth' 112;
    font-size: var(--text-label);
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
    color: var(--color-dim);
  }

  .readout {
    font-family: var(--font-display);
    font-variation-settings: 'wdth' 112;
    /* The number is the hero of its row rather than body text that happens to be a figure. */
    font-variant-numeric: tabular-nums;
    font-size: var(--text-label);
    font-weight: var(--font-weight-bold);
    color: var(--color-white);
  }

  .track {
    position: relative;
    height: var(--bar-height);
    overflow: hidden;

    background: var(--surface-sunken);
    /* Nested and opaque: settles the scrim rather than inheriting a halo onto a 10px bar. */
    text-shadow: none;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-xs);
  }

  /* Notches are cells with gaps, so the track stops being a container and becomes a row. */
  .track.notched {
    display: flex;
    gap: var(--hatch-step);
    background: transparent;
    border: 0;
    overflow: visible;
  }

  .cell {
    flex: 1;
    background: var(--surface-sunken);
    /* Opaque and nested, so it settles the scrim rather than inheriting one onto a notch. */
    text-shadow: none;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-xs);
    transition: background-color var(--dur-fast) var(--ease-out);
  }

  .fill {
    position: absolute;
    inset: 0 auto 0 0;
    /* The hatch IS the fill; there is no flat under-colour. A solid band with stripes on top
       reads as a bar with a texture, which is the thing this is not. */
    background-image: repeating-linear-gradient(
      var(--hatch-angle),
      var(--tone-colour) 0 var(--hatch-step),
      transparent var(--hatch-step) var(--hatch-gap)
    );

    /* An ease over `--dur-base` for a value that jumps when something happens; exactly one tick,
       linear, for one fed by a clock. Both are set inline by the `tick` prop and absent
       otherwise, so the fallbacks are the whole default. */
    transition: width var(--bar-dur, var(--dur-base)) var(--bar-ease, var(--ease-out));
  }

  .marker {
    position: absolute;
    top: 0;
    bottom: 0;
    width: 2px;
    /* The idle accent, whatever the fill is doing: a marker is where this run *stops*, which is a
       statement about the future, and the fill is a statement about now. */
    background: var(--color-primary);
    transform: translateX(-1px);
  }

  /* Counted, but too many to draw as cells — a hard-stopped solid, so it still reads as
     counted rather than turning into the accumulating one. */
  .fill.solid {
    background-image: none;
    background-color: var(--tone-colour);
  }

  .primary { --tone-colour: var(--color-primary); }
  .action { --tone-colour: var(--color-action); }
  .live { --tone-colour: var(--color-live); }
  .success { --tone-colour: var(--color-success); }
  .warn { --tone-colour: var(--color-warn); }
  .danger { --tone-colour: var(--color-danger); }

  .track.primary .cell.on,
  .track.action .cell.on,
  .track.live .cell.on,
  .track.success .cell.on,
  .track.warn .cell.on,
  .track.danger .cell.on {
    background: var(--tone-colour);
    border-color: var(--tone-colour);
  }
  /* Ambient: the caption and the readout in white, the tree's rule over the game. */
  .ambient .label,
  .ambient .readout {
    color: var(--color-white);
  }
</style>

