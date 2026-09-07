<script lang="ts">
  /**
   * The persistent hint cluster: what the keys and the mouse do, right now, on this surface.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * Trait 3 of `docs/ui-tdu.md`, and the note there is blunt about the starting position: *"no such
   * convention anywhere; two ad-hoc components"*. Nine resources touch `KeyGlyph` or `lib.showHints`
   * and each arranges them differently.
   *
   * ## This is the *in-page* half, and `lib.showHints` is the other one
   *
   * They are not rivals and the difference decides which to reach for:
   *
   * - **`lib.showHints`** draws at the bottom centre of the *screen*, for hints that belong to the
   *   world — walking up to a door, holding a key to enter. It is Lua's and it survives the page.
   * - **This** draws inside a panel, for hints that only exist while that panel is open.
   *
   * `ghst_appearance` needed the second and had to hand-roll it, because the bottom centre of its
   * screen belongs to the character being dressed: the frame chips and the peek row live there, and
   * a screen-wide hint bar would have landed on top of them.
   *
   * ## A mouse gesture is not a key
   *
   * `Drag`, `Wheel` and `Hold` get a word in the same face and tracking as a key glyph but **no
   * box**, because a box is what says *this is a thing on your keyboard*. Inventing a key-shaped
   * mouse glyph would be the only fabricated key shape in the tree, and it would be fabricated in
   * the one component whose whole job is telling the truth about controls.
   */
  import type { Snippet } from 'svelte';
  import KeyGlyph from './KeyGlyph.svelte';

  interface Hint {
    /**
     * The key, as its resolved label: `esc`, `E`, `↑↓`. Drawn here with `KeyGlyph`, so a hint is
     * DATA and a caller can build a list of them from a table -- which the first version could
     * not: it took each key as a snippet, and a snippet cannot be made at runtime, so the gallery
     * ended up carrying twelve one-line snippets and a lookup to draw five hints (2026-09-04).
     *
     * This file now imports `KeyGlyph`, which it once refused to do on the argument that a copied
     * file importing another copied file is how a copy lands without its dependency. That risk is
     * real and is answered where it belongs: `Tools/checks/copies.py` asserts that any resource
     * carrying this file carries `KeyGlyph` too.
     */
    key?: string;
    /** `round` for a controller face button; decided by Lua, never guessed. */
    shape?: 'key' | 'round';
    /** Still accepted: a caller that draws its own glyphs. `key` wins if both are given. */
    keys?: Snippet;
    /** A mouse gesture, drawn as a word with no box: `Drag`, `Wheel`, `Hold`. */
    verb?: string;
    /** What it does. Sentence case, two words where possible — `Turn`, `Back`, `Checkout`. */
    does: string;
  }

  interface Props {
    hints: Hint[];
    /**
     * `rows` stacks into two columns and is for a corner cluster; `inline` is a single line, for a
     * strip along the bottom of a panel.
     */
    layout?: 'rows' | 'inline';
    /**
     * Where this sits. `panel` is inside a focused panel and may use the grey tiers; `ambient` is
     * over the moving game -- a plate at the screen's edge, a world prompt -- where the tree's rule
     * is that type is white and hierarchy comes from weight. Four screens in the gallery had grey
     * hint labels vanish over the noon sky before this existed.
     */
    tone?: 'panel' | 'ambient';
  }

  let { hints, layout = 'rows', tone = 'panel' }: Props = $props();
</script>

<ul class="hints {layout} {tone}">
  {#each hints as hint, index (index)}
    <li>
      {#if hint.key}<KeyGlyph label={hint.key} shape={hint.shape} />{:else if hint.keys}{@render hint.keys()}{/if}
      {#if hint.verb}<span class="verb">{hint.verb}</span>{/if}
      <span class="does">{hint.does}</span>
    </li>
  {/each}
</ul>

<style>
  /*
   * No surface, ever. These sit on whatever is behind them and carry their own legibility through
   * the scrim — a plate would make a hint cluster a panel, and it is the least important thing on
   * any screen it appears on.
   */
  .hints {
    display: grid;
    gap: var(--space-1) var(--space-3);
    color: var(--color-dim);
    font-size: var(--text-meta);
  }

  /* Two columns, so four hints are a compact block in a corner rather than a tall list. */
  .hints.rows {
    grid-template-columns: 1fr 1fr;
  }

  .hints.inline {
    grid-auto-flow: column;
    justify-content: start;
  }

  /*
   * `--legible-text`, not `--ink-scrim`, and the distinction is which of two treatments this is.
   *
   * The scrim is for ink sitting inside a glass plane; the four-offset shadow is for words drawn
   * straight onto the world. **This component paints no ground anywhere** -- a hint bar is type on
   * the scene by construction, which is the whole reason it can be always-on and take no focus --
   * so it was wearing the wrong one, and against a bright wall the difference is whether the hints
   * are legible at all. Found 2026-09-04 by the fourth rule in `Tools/checks/glass.py`, after the
   * same fault turned up three times over in `ghst_appearance`'s shop.
   */
  .hints li {
    display: flex;
    align-items: center;
    gap: var(--space-1-5);
    text-shadow: var(--legible-text);
  }

  /* A key's lettering with no key's box. See the header. */
  .verb {
    color: var(--color-gray);
    font-family: var(--font-display);
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
  }

  .does {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Ambient: white, all of it. There is no grey tier over the game. */
  .ambient,
  .ambient .verb {
    color: var(--color-white);
  }
</style>
