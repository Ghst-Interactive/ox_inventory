<script lang="ts">
  /**
   * A count you step and can also type: down, the number, up.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** -- see `Row.svelte` for the licence routing.
   *
   * Written for the review of 2026-09-05, which found the same control hand-rolled four times --
   * the shop row's − / + pair, the mod shop's level chips, the HUD editor's cell fields, and the
   * inventory's split, which had only a slider and *"cannot land on 7"*. It is one control with
   * three parts, not two `Button`s beside a number: the parts share one border, the number is the
   * thing you read, and the steppers are the thing you reach for.
   *
   * THE DIGIT IS TYPED. `inputmode="numeric"` and a plain text input rather than `type="number"`,
   * because Chromium's spinner cannot be themed and the tree already hides it everywhere (see the
   * `NumberField` note in ghst_hud). A typed value commits on change and is clamped; a value that
   * is not a number leaves the count where it was.
   *
   * `compact` is for a row's trailing slot, where the control sits beside a price and should not
   * be taller than the row's text.
   */
  interface Props {
    value: number;
    min?: number;
    max?: number;
    step?: number;
    /** The accessible name of the count: "Quantity", "Level", "How many". */
    label: string;
    compact?: boolean;
    disabled?: boolean;
    onchange?: (value: number) => void;
  }

  let {
    value = $bindable(0),
    min = 0,
    max = Number.POSITIVE_INFINITY,
    step = 1,
    label,
    compact = false,
    disabled = false,
    onchange,
  }: Props = $props();

  /* Text kept beside the number so a half-typed digit does not fight the clamp on every keystroke;
     it is reconciled on commit and whenever the value changes underneath. */
  let text = $state(String(value));
  $effect(() => {
    text = String(value);
  });

  function set(next: number): void {
    const clamped = Math.min(max, Math.max(min, next));
    if (clamped === value) {
      text = String(value);
      return;
    }
    value = clamped;
    onchange?.(clamped);
  }
  function commit(): void {
    const n = Number(text);
    set(Number.isFinite(n) ? Math.round(n / step) * step : value);
  }
</script>

<span class="stepper" class:compact class:disabled role="group" aria-label={label}>
  <button type="button" aria-label="Decrease" disabled={disabled || value <= min} onclick={() => set(value - step)}>−</button>
  <!--
    `size` IS LOAD-BEARING, and its absence was a layout bug rather than a nicety.

    A text input with no `size` has an intrinsic width of twenty characters, and a percentage
    width does not change that -- for intrinsic sizing a `%` behaves as `auto`, so `width: 100%`
    below fixes how the input *fills* its track and not what it *asks* for. The middle track is
    `minmax(_, auto)`, whose max is max-content, so the track asked for ~149px and got it: in
    `ghst_shops` that left a 420px row with a 199px stepper and 56px for the item's name, and a
    refusal wrapped over three lines (seen in the browser 2026-09-06).

    Sized off the value instead, with a floor of two so a single digit does not make a control
    narrower than its own steppers. The track's `minmax` still owns the minimum; this only stops
    the browser's default from being the maximum.
  -->
  <input
    type="text"
    size={Math.max(2, text.length)}
    inputmode="numeric"
    autocomplete="off"
    spellcheck="false"
    aria-label={label}
    {disabled}
    bind:value={text}
    onchange={commit}
    onkeydown={(e) => {
      if (e.key === 'Enter') commit();
      else if (e.key === 'ArrowUp') {
        e.preventDefault();
        set(value + step);
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        set(value - step);
      }
    }}
  />
  <button type="button" aria-label="Increase" disabled={disabled || value >= max} onclick={() => set(value + step)}>+</button>
</span>

<style>
  .stepper {
    display: inline-grid;
    height: var(--control-h);
    align-items: stretch;
    overflow: hidden;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--tint-sunken);
    grid-template-columns: var(--control-h) minmax(2.6em, auto) var(--control-h);
    font-variant-numeric: tabular-nums;
  }
  .stepper.compact {
    height: calc(24 * var(--ui-px));
    border-radius: var(--radius-sm);
    grid-template-columns: calc(24 * var(--ui-px)) minmax(2em, auto) calc(24 * var(--ui-px));
  }
  .stepper.disabled {
    opacity: 0.5;
  }
  button {
    display: grid;
    place-items: center;
    color: var(--color-dim);
    font-size: var(--text-base);
    font-weight: var(--font-weight-bold);
    line-height: 1;
    cursor: pointer;
    transition:
      background-color var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out);
  }
  button:hover:not(:disabled) {
    background-image: var(--layer-hover);
    color: var(--color-white);
  }
  button:disabled {
    color: var(--color-dim);
    opacity: 0.4;
    cursor: not-allowed;
  }
  input {
    width: 100%;
    min-width: 0;
    padding: 0 var(--space-1);
    background: none;
    color: var(--color-white);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    font-weight: var(--font-weight-bold);
    text-align: center;
    outline: none;
  }
  .compact input {
    font-size: var(--text-meta);
  }
  input:focus {
    background: var(--primary-glow);
  }
</style>
