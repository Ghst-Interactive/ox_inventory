<script lang="ts">
  /**
   * A text input: a row that owns the edge, with an optional glyph in front and a clear button
   * behind.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * ## Scope, which is narrower than "a form control"
   *
   * Counted across the tree on 2026-09-04: 11 checkboxes, 10 ranges, 2 dates, 1 colour — and every
   * other input is a bare `<input>` taking its default type. So the thing written over and over is
   * *this* one, and the others already have owners:
   *
   * - **Checkboxes stay native**, styled with `accent-color`. That is a tree rule with a reason
   *   behind it — a re-implemented checkbox loses the platform's own focus and indeterminate
   *   states, and gains nothing but a tick of a different shape.
   * - **Ranges are `Slider`**, which resources already carry.
   * - **Numbers are `NumberField`** in `ghst_hud`: Chromium's spinners cannot be themed, so they
   *   are hidden and chevrons are overlaid. That is a different control with a different problem
   *   and folding it in here would make this file about spinners.
   *
   * So: text and search, and nothing else.
   *
   * ## `type="text"`, never `type="search"`
   *
   * Chromium draws its own clear affordance inside a search input and it cannot be themed —
   * the same reason `NumberField` hides the native spinners. The clear button here is ours, which
   * is also what lets it be absent until there is something to clear.
   *
   * ## The keys it swallows, and why that is the component's job
   *
   * A field is almost always inside something else that is listening, and getting this wrong is
   * silent. `ghst_appearance` put a search box inside a grid that steps on arrow keys and **wears
   * the garment it steps to** — so a left-arrow moving the caret would dress the character — and
   * inside a page with a window-level Escape that backs out a level, so clearing a query and
   * leaving the slot were one keystroke.
   *
   * Left and right stop here, because they are the caret's. Up and down are deliberately let
   * through, because they do nothing useful in a single-line input and letting them fall to the
   * host is what makes "type, then press down into the results" work. Escape stops **only while
   * there is something to clear**; with an empty box it belongs to whoever wants to close the
   * panel, or the field becomes a trap you have to click out of.
   *
   * ## Five callers, found later, and what they added
   *
   * This file was written from a count of input *types*. Re-passing the resources on 2026-09-04
   * turned up the other half of the picture: **five filter boxes**, in `ghst_emotes`,
   * `ghst_appearance` (twice), `ox_inventory` and `ghst_customs`, each hand-rolled and each the
   * same object as this one. They were nearly identical to each other, and two of them explain
   * themselves in the same words — *"FOCUS IS A RAIL AND A WASH, the same two marks the rows
   * below it take"*.
   *
   * That sentence is the correction they brought back. This file lit **all four borders** in
   * `--color-primary` on focus, with no wash and no reserved edge, which is the web form's frame
   * that four of the five had already stopped drawing: every "you are on this" in the tree is a
   * 2px accent edge down the left plus an 8% accent wash, and the edge is reserved as transparent
   * at rest so focus does not move the box by two pixels.
   *
   * `ox_inventory` brought the second: **a field holding a query while the caret is elsewhere.** A
   * player reading a filtered grid needs to know the grid is filtered, and full focus decoration
   * on a box nobody is typing in says the opposite. It is derived from the value rather than
   * passed — a field with something in it is filled, and that is not a fact a caller can hold an
   * opinion about — and it must come **before** the focus rule in this file, because the two weigh
   * the same and order is the whole of the precedence. `ox_inventory` had them the other way and a
   * focused-and-filled box lost its rail.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    value: string;
    /** Accessible name. Required — a bare input in a panel is a box with no purpose stated. */
    label: string;
    placeholder?: string;
    /** A leading glyph, rendered by the caller so this file needs no icon library. */
    glyph?: Snippet;
    /** The clear button's glyph. Absent means no clear button, however much is typed. */
    clearGlyph?: Snippet;
    /**
     * What the clear button does instead of emptying the field.
     *
     * **Clearing a filter and leaving one are different verbs**, and one of the five boxes this
     * absorbed is a *mode* rather than a control: `ghst_customs`' find box takes the place of the
     * tab row's title while it is open, so its X puts the tabs back rather than emptying the
     * query, and `/` is how you get it again.
     *
     * With this set the button is drawn whether or not anything is typed, because a mode you
     * cannot leave while it is empty is a trap.
     */
    onclear?: () => void;
    /**
     * The input itself, for a caller that focuses the field when its panel opens.
     *
     * `ghst_emotes` opens its menu straight into the search — *"1,075 rows is not a list you
     * browse"* — and `ghst_customs` focuses on `/`. Both need to reach the element from outside
     * the component that draws it.
     */
    element?: HTMLInputElement;
    disabled?: boolean;
    /**
     * The server's own cap, passed through to the input.
     *
     * Not styling — a *contract*. `ghst_multichar`'s creation form is the case that asked for it:
     * qbx_core's `sanitizeNewCharInfo` **rejects** an over-length name rather than truncating it,
     * and returns nil for the whole character. A form that let one character more through than the
     * server takes would give a player a Create button that appears to work and silently does
     * nothing, with nothing on screen saying which of six fields was the problem.
     *
     * So the cap belongs on the element, where the browser enforces it at the keystroke, rather
     * than in a check that runs after the damage.
     */
    maxlength?: number;
    /**
     * Marked wrong by whoever is validating.
     *
     * Held by the caller and not derived here, unlike `filled`: what makes a value wrong is the
     * form's business, and this file has no opinion about it. The one thing it decides is what
     * wrong LOOKS like, and the answer is the border and nothing else — a red wash would make an
     * empty field read as an error state rather than as an empty one, which is the note
     * `ghst_multichar`'s hand-rolled fields carried before they became this component.
     */
    invalid?: boolean;
    onenter?: () => void;
  }

  let {
    value = $bindable(''),
    label,
    placeholder,
    glyph,
    clearGlyph,
    onclear,
    element = $bindable(),
    disabled = false,
    maxlength,
    invalid = false,
    onenter,
  }: Props = $props();

  const filled = $derived(value.trim() !== '');

  function keys(event: KeyboardEvent) {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') return event.stopPropagation();

    if (event.key === 'Escape' && value !== '') {
      event.stopPropagation();
      value = '';

      return;
    }

    if (event.key === 'Enter' && onenter) {
      event.stopPropagation();
      onenter();
    }
  }
</script>

<div class="field" class:disabled class:filled class:invalid>
  {#if glyph}<span class="glyph">{@render glyph()}</span>{/if}

  <input
    bind:this={element}
    type="text"
    autocomplete="off"
    spellcheck="false"
    aria-label={label}
    aria-invalid={invalid || undefined}
    {placeholder}
    {disabled}
    {maxlength}
    bind:value
    onkeydown={keys}
  />

  {#if clearGlyph && (onclear || value)}
    <button
      class="clear"
      type="button"
      aria-label={onclear ? 'Stop searching' : 'Clear'}
      onclick={() => (onclear ? onclear() : (value = ''))}
    >
      {@render clearGlyph()}
    </button>
  {/if}
</div>

<style>
  /*
   * The ROW owns the edge, not the input.
   *
   * A bordered input inside a bordered panel inside a bordered column is three rectangles deep
   * before any content — which the square corner scale makes obvious rather than hides. The input
   * is transparent and borderless; this is the control.
   */
  .field {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: 0 var(--space-2);
    border: 1px solid var(--color-border);
    /* RESERVED AT REST, exactly as a list row reserves it, so focus does not shove the glyph and
       the text two pixels right on the first keystroke. Four of the five fields this absorbed had
       written this line and three of them said why. */
    border-left: 2px solid transparent;
    border-radius: var(--radius-md);
    background: var(--surface-sunken);
    /* Settled, not inherited. This plate is opaque, so a scrim carried down from whatever glass
       hosts it would be a halo under text that has a solid ground of its own -- smudge. */
    text-shadow: none;
    color: var(--color-dim);
    transition:
      background-color var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out);
  }

  /*
   * Something typed, with the caret somewhere else. Quieter than focus and deliberately so: the
   * player is reading the filtered list, and the field's job is to say *why* it is short.
   *
   * FIRST, so focus wins where the two overlap -- see the header. Both selectors weigh the same,
   * so order is the whole of the precedence.
   */
  .field.filled {
    border-color: var(--primary-glow-border);
    color: var(--color-primary);
  }

  /*
   * FOCUS IS A RAIL AND A WASH — `InputRow`'s `.control:focus`, on the row because the input has
   * no edge of its own to light.
   *
   * This was `border-color: var(--color-primary)` on all four sides, which is a web form's frame
   * rather than this tree's mark. Every "you are on this" here is a 2px accent edge down the left
   * plus an 8% accent wash.
   */
  .field:focus-within {
    border-color: var(--primary-glow-border);
    border-left-color: var(--color-primary);
    background-color: var(--primary-glow);
    color: var(--color-primary);
  }

  /*
   * WRONG, and it is the border alone.
   *
   * **After focus, and specific enough to survive it.** The two states genuinely overlap — you fix
   * a bad field by typing in it — so both have to be readable at once: the danger edge says which
   * field, the accent rail and wash say where the caret is. Written as one rule each rather than
   * as a single `border-color`, because the shorthand sets the left edge too and would eat the
   * rail the moment the player clicked into the thing they were being asked to correct.
   */
  .field.invalid {
    border-color: var(--color-danger);
  }

  .field.invalid:focus-within {
    border-top-color: var(--color-danger);
    border-right-color: var(--color-danger);
    border-bottom-color: var(--color-danger);
    border-left-color: var(--color-primary);
  }

  .field.disabled {
    opacity: 0.55;
  }

  .glyph {
    display: grid;
    flex: none;
    place-items: center;
    color: var(--color-dim);
  }

  input {
    min-width: 0;
    flex: 1;
    padding: var(--space-2) 0;
    border: 0;
    background: none;
    color: var(--color-white);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  input::placeholder {
    color: var(--color-dim);
  }

  /* The row carries the focus ring, so the input drawing its own would be two rings a pixel
     apart. */
  input:focus {
    outline: none;
  }

  /* Round, unlike the row it sits in: panels and rows are square in this tree and the controls
     inside them stay round, and this is the one control on the row. */
  .clear {
    display: grid;
    width: calc(20 * var(--ui-px));
    height: calc(20 * var(--ui-px));
    flex: none;
    place-items: center;
    border-radius: var(--radius-full);
    color: var(--color-dim);
    transition: color var(--dur-fast) var(--ease-out);
  }

  .clear:hover {
    background-image: var(--layer-hover);
    color: var(--color-white);
  }
</style>
