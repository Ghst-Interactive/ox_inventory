<script lang="ts">
  /**
   * ONE COUNT CONTROL, for Give, Split and Drop alike.
   *
   * The design walk's row for this resource named the fault directly: the split prompt had
   * only a slider, which "cannot land on 7" — and Give and Drop asked the same question
   * (Give with the fixed pre-typed amount box, Drop not at all) in two other shapes. This is
   * the one answer: an exact typed digit with `Stepper`'s arrows, a slider for a fast sweep,
   * and One / Half / All as the three shortcuts to the same field. Every caller reads and
   * writes the same `value`; what differs between Give, Split and Drop is only the dialog
   * around this and the NUI message the confirm button sends — those stay theirs.
   */
  import Stepper from '../lib/Stepper.svelte';
  import SegmentedNav from '../lib/SegmentedNav.svelte';
  import { locale } from '../lib/state.svelte';

  interface Props {
    value: number;
    /** The most this count may reach — the stack size, or how many are on the ground. */
    max: number;
    /** The accessible name of the count, and the caption above it. */
    label?: string;
  }

  let { value = $bindable(1), max, label }: Props = $props();

  const half = $derived(Math.max(1, Math.round(max / 2)));

  function set(next: number) {
    value = Math.max(1, Math.min(max, Math.round(next) || 1));
  }
</script>

<div class="count">
  <div class="head">
    <span class="label">{label ?? locale.ui_how_many ?? 'How many'}</span>
    <span class="of">{locale.ui_of || 'of'} {max.toLocaleString('en-us')}</span>
  </div>

  <Stepper value={Math.min(value, max)} min={1} {max} label={label ?? 'How many'} onchange={set} />

  <input
    class="slider"
    type="range"
    min="1"
    {max}
    step="1"
    value={Math.min(value, max)}
    oninput={(e) => set(+(e.currentTarget as HTMLInputElement).value)}
    aria-label={label ?? 'How many'}
  />

  <SegmentedNav
    label={locale.ui_quick || 'Quick'}
    variant="loose"
    value={String(Math.min(value, max))}
    options={[
      { value: '1', label: locale.ui_one || 'One' },
      { value: String(half), label: locale.ui_half || 'Half' },
      { value: String(max), label: locale.ui_all || 'All' },
    ]}
    onchange={(n) => set(+n)}
  />
</div>

<style>
  .count {
    display: flex;
    flex-direction: column;
    gap: var(--space-1-5);
  }

  .head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .label {
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    font-family: var(--font-display);
    text-transform: uppercase;
    color: var(--color-dim);
  }

  .of {
    font-family: var(--font-mono);
    font-size: var(--text-meta);
    color: var(--color-dim);
    white-space: nowrap;
  }

  .slider {
    width: 100%;
    accent-color: var(--color-primary);
  }
</style>
