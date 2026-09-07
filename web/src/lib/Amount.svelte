<script lang="ts">
  /**
   * An amount, entered once: a caption, a unit, a field, and the usual figures as chips.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** -- see `Row.svelte` for the licence routing.
   *
   * Banking, the exchange and the shop counter each asked for a number and each drew its own
   * field, its own quick chips and its own commit -- three answers to one question (review
   * 2026-09-04). This is the field and the chips; the COMMIT IS THE CALLER'S, because the walk
   * settled that the verb folds into it: *Deposit $500*, *Buy 10 GHC · $2,290*. A component that
   * owned the button would own the verb, and the verb is what differs.
   *
   * The chips are `Button`s, `selected` when the field holds their value exactly; typing anything
   * else un-selects them all, which is the honest state. There is deliberately no formatting here:
   * `hint` and the chip labels arrive already written, because currency and locale are
   * `lib/format.ts`'s and not a form control's.
   *
   * `Field` is text and not `type="number"` for the reason `Stepper` gives; `inputmode="numeric"`
   * brings the right keyboard where there is one.
   */
  import Field from './Field.svelte';
  import Button from './Button.svelte';

  interface Chip {
    label: string;
    value: string;
  }
  interface Props {
    value: string;
    /** The caption over the field: "Amount", "Units", "To". */
    label: string;
    /** Drawn before the field, in the display face: "$", "GHC", "#". */
    unit?: string;
    chips?: Chip[];
    /** A note at the caption's right: "Up to $12,000". */
    hint?: string;
    placeholder?: string;
    disabled?: boolean;
    onenter?: () => void;
  }

  let {
    value = $bindable(''),
    label,
    unit,
    chips = [],
    hint,
    placeholder = '0',
    disabled = false,
    onenter,
  }: Props = $props();
</script>

<div class="amount" class:disabled>
  <div class="cap">
    <span class="label">{label}</span>
    {#if hint}<span class="hint">{hint}</span>{/if}
  </div>
  <div class="entry" class:unit>
    {#if unit}<span class="u">{unit}</span>{/if}
    <Field bind:value {label} {placeholder} {disabled} {onenter} />
  </div>
  {#if chips.length}
    <div class="chips">
      {#each chips as chip (chip.value)}
        <Button selected={value === chip.value} {disabled} onclick={() => (value = chip.value)}>{chip.label}</Button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .amount {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }
  .amount.disabled {
    opacity: 0.6;
  }
  .cap {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--space-3);
  }
  /* The eyebrow recipe every panel uses for a caption. */
  .label {
    color: var(--color-dim);
    font-family: var(--font-display);
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
  }
  .hint {
    color: var(--color-dim);
    font-size: var(--text-meta);
  }
  .entry {
    display: grid;
    align-items: center;
    gap: var(--space-2);
    grid-template-columns: 1fr;
  }
  .entry.unit {
    grid-template-columns: auto 1fr;
  }
  /* The figure is what you read, so the field's text is the number's size, in mono. */
  .entry :global(input) {
    font-family: var(--font-mono);
    font-size: var(--text-heading);
    font-variant-numeric: tabular-nums;
  }
  .u {
    color: var(--color-dim);
    font-family: var(--font-display);
    font-size: var(--text-heading);
    font-weight: var(--font-weight-bold);
  }
  .chips {
    display: grid;
    gap: var(--space-2);
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
  }
</style>
