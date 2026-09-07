<script lang="ts">
  /**
   * A small static label: a tier, a caveat, a state. Not a count and not a control.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * ## Narrower than the survey suggests, and deliberately
   *
   * Counting `chip`, `count`, `badge`, `tally`, `tag` and `pill` across the tree finds 63 sites,
   * and it would be a mistake to point one component at all of them — they are four different
   * things wearing similar clothes:
   *
   * - **a count on a row** — `Row`'s `meta` owns it, and it is tabular for a reason
   * - **a pip on a tab** — `SegmentedNav`'s `badge` owns it, and it inverts on the active chip
   * - **a filter chip you can click** — that is a control, and it is `Button` or a tab strip
   * - **a static label** — "Police only", "Gen9", "Discount", "Sold out". *This.*
   *
   * The test is whether it is clickable and whether it is a number. If either, it is not this.
   *
   * ## Tone is a claim about meaning, not a colour picker
   *
   * `warn` for a caveat that still lets you proceed, `danger` for a refusal, `live` for something
   * happening now, `primary` for identity. A caller reaching for a tone because it looks right is
   * how a red badge ends up meaning "new" on one panel and "blocked" on the next.
   */
  import Rhombus from './Rhombus.svelte';

  interface Props {
    label: string;
    tone?: 'neutral' | 'primary' | 'live' | 'warn' | 'danger';
    /**
     * Draw the rhombus mark before the label.
     *
     * For a badge that is a *tier* rather than a caveat — the house mark repeated at every scale,
     * which is trait 9. A caveat with a mark on it reads as a brand endorsing the caveat.
     */
    mark?: boolean;
  }

  let { label, tone = 'neutral', mark = false }: Props = $props();
</script>

<span class="badge {tone}">
  {#if mark}<Rhombus scale={0.55} />{/if}
  {label}
</span>

<style>
  /*
   * Square, not a pill. A badge is a *label* rather than a control, and this tree keeps rounding
   * for the things you can press — a fully-rounded static tag beside a square row is the thing
   * that makes a list look like two designs.
   */
  .badge {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: calc(2 * var(--ui-px)) var(--space-1-5);
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    font-family: var(--font-display);
    font-size: var(--text-micro);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    line-height: 1;
    text-transform: uppercase;
    white-space: nowrap;
  }

  /*
   * Tinted ground plus a full-strength edge and ink, rather than a filled block.
   *
   * A solid badge at this size is a bright rectangle that outweighs the row it annotates — the
   * label is a footnote and has to read as one. The border is what keeps it legible once the
   * ground is that faint.
   */
  .neutral {
    border-color: var(--color-border);
    background: var(--tint-raised);
    color: var(--color-gray);
  }

  .primary {
    border-color: var(--primary-glow-border);
    background: var(--primary-glow);
    color: var(--color-primary);
  }

  .live {
    border-color: var(--color-action);
    background: var(--action-glow);
    color: var(--color-action);
  }

  .warn {
    border-color: var(--color-warn);
    color: var(--color-warn);
  }

  .danger {
    border-color: var(--color-danger);
    color: var(--color-danger-text);
  }
</style>
