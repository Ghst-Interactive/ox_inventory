<script lang="ts">
  /**
   * A button, in the weights this system has.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** -- see `Row.svelte` for the licence routing.
   * It used to be the template's, and the template's file is GPL, so it could reach every
   * `ghst_*` and `ox_inventory` and never this library -- which meant the two dialogs that every
   * resource without a page of its own is drawn through could not use the one button the tree
   * agreed on. Rewritten here (2026-09-05), the same contract and a third weight, so the template's
   * copy is now a copy of this one. Change it here.
   *
   * THREE WEIGHTS AND NO MORE.
   *
   * - `neutral` is a surface with a hairline. The ordinary button.
   * - `filled` is the accent, and there is AT MOST ONE on a screen at a time. That ceiling is the
   *   whole design: the accent means *this is the thing to press*, and a screen with two of them
   *   has answered the question twice. `--color-on-accent` exists because white on the cyan is
   *   about 1.9:1 and fails at any size.
   * - `ghost` is no surface at all: a glyph or a word that lights on hover. For the control that
   *   rides on a row -- favourite, bind, revert, close -- where a list of a thousand things with a
   *   bordered box per row is a wall of boxes. It carries no text of its own weight and should
   *   almost always come with a `label`.
   *
   * `selected` is a state, not a weight. A neutral button that is currently ON -- a camera mode, a
   * dock side, a chip in an amount row -- fills in, because at that moment it IS the answer. On a
   * ghost it lights the glyph in the accent instead of filling, because a ghost has no plate to fill.
   *
   * SIZED FROM THE THEME. `--btn-pad-x`, `--btn-pad-y`, `--btn-text` and `--btn-border` are tokens
   * so a menu button and a compact one in an ambient toolbar are the same component under
   * different values -- the mod shop's puck and the HUD's arranging bar both override them on a
   * wrapper rather than carrying a button of their own.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    variant?: 'neutral' | 'filled' | 'ghost';
    /** Currently on. Fills a neutral, lights a ghost; ignored on `filled`. */
    selected?: boolean;
    disabled?: boolean;
    /** Passed through as the accessible name. Required in practice for an icon-only button. */
    label?: string;
    /**
     * `submit` for the one button that completes a form, so Enter in a field still works. The
     * default is `button` because a bare `<button>` inside a `<form>` submits, and a component that
     * did not say otherwise would make every incidental control in a form a submit.
     */
    type?: 'button' | 'submit';
    onclick?: () => void;
    children?: Snippet;
  }

  let {
    variant = 'neutral',
    selected = false,
    disabled = false,
    label,
    type = 'button',
    onclick,
    children,
  }: Props = $props();
</script>

<button
  {type}
  class="btn {variant}"
  class:on={selected}
  {disabled}
  aria-label={label}
  aria-pressed={selected || undefined}
  {onclick}
>
  {@render children?.()}
</button>

<style>
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    padding: var(--btn-pad-y) var(--btn-pad-x);
    border: var(--btn-border) solid transparent;
    border-radius: var(--radius-md);
    background: none;
    color: var(--color-white);
    font-family: inherit;
    font-size: var(--btn-text);
    font-weight: var(--font-weight-bold);
    line-height: 1.2;
    cursor: pointer;
    transition:
      border-color var(--dur-fast) var(--ease-out),
      background-color var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out);
  }
  .btn:disabled {
    cursor: not-allowed;
  }

  /* NEUTRAL: a plate with a hairline. Hover moves the edge, not the ground -- the same rule a row
     follows, because a button that changes surface under the pointer reads as a different material. */
  .neutral {
    border-color: var(--color-border);
    background: var(--color-surface);
  }
  .neutral:hover:not(:disabled) {
    border-color: var(--color-primary);
  }
  .neutral:disabled {
    color: var(--color-dim);
  }

  /* FILLED, and a NEUTRAL that is ON: the accent, with its own ink. The hover is the ink washed
     over the fill, per the state-layer rule -- the wash takes the colour of the content, because a
     white wash over the cyan is invisible. */
  .filled,
  .neutral.on {
    border-color: var(--color-primary);
    background: var(--color-primary);
    color: var(--color-on-accent);
  }
  .filled:hover:not(:disabled),
  .neutral.on:hover:not(:disabled) {
    background-image: linear-gradient(rgba(4, 37, 43, 0.08), rgba(4, 37, 43, 0.08));
  }
  .filled:disabled,
  .neutral.on:disabled {
    opacity: 0.45;
  }

  /* GHOST: nothing until you reach it. Square-ish by default so a lone glyph gets a target the
     size of a row's height; the hover is the state layer, not a border, because a border is a
     plate. */
  .ghost {
    min-width: var(--control-h);
    min-height: var(--control-h);
    padding: 0 var(--space-2);
    border-radius: var(--radius-sm);
    color: var(--color-dim);
  }
  .ghost:hover:not(:disabled) {
    background-image: var(--layer-hover);
    color: var(--color-white);
  }
  .ghost.on {
    color: var(--color-primary);
  }
  .ghost:disabled {
    opacity: 0.4;
  }
</style>
