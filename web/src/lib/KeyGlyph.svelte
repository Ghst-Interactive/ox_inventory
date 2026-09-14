<script lang="ts">
  /**
   * One key, drawn as a key.
   *
   * The atom the whole hint layer is built from, and the reason it lives in ox_lib: eight
   * resources on this server have no `web/` of their own and draw entirely through this
   * library, and the point of a key-hint convention is that it is the same convention
   * everywhere.
   *
   * ONE FILE WITH COPIES. A Svelte component cannot be imported across a NUI resource
   * boundary -- each `web/` is its own bundle -- so a resource drawing its own key glyph has
   * to carry this file rather than reference it. `Tools/checks/copies.py` holds the copies to
   * byte identity for the same reason it holds `prefs.svelte.ts`: a key that looks different
   * in the chat than it does on a garage's textUI is two answers to a question with one.
   *
   * **Changed in `ox_lib` first and copied out**, to `Tools/ghst_template` and every resource that
   * carries it -- ox_lib's own dialogs and list menu draw it, and LGPL can reach GPL but not the
   * other way. See `Row.svelte`'s header in the template for the routing.
   */

  interface Props {
    /** Already resolved by Lua. This component never guesses what a key is called. */
    label: string;
    /**
     * How to draw it. `key` is a keyboard key; `round` is a controller face button.
     *
     * ASKED FOR, NOT INFERRED -- unlike `wide` below, and the difference is worth stating. `wide`
     * is a fact about the label, which this component is holding. Whether `A` means the A button
     * or the letter A is a fact about the *input device*, which it is not: only Lua knows, and
     * `ox_lib`'s `hints.lua` says so alongside the label rather than making the page guess from a
     * one-character string it cannot tell apart.
     */
    shape?: 'key' | 'round';
    disabled?: boolean;
    /**
     * The key is down right now.
     *
     * **The whole of what a prompt was missing.** A glyph that never moves says what to press and
     * never says it was heard; sleepless_prompts' prompts felt alive for exactly one reason, which
     * is that the key lit when the player pressed it. Only the caller knows -- Lua reads the game's
     * input -- so it is asked for, like `shape`.
     */
    pressed?: boolean;
    /**
     * How far through a hold, 0 to 1. Absent or 0 draws no fill.
     *
     * **Inside the key, not under it.** A bar beneath the row is a second object to look at; the
     * key filling is the thing being held answering the thumb holding it.
     */
    progress?: number;
  }

  let { label, shape = 'key', disabled = false, pressed = false, progress = 0 }: Props = $props();

  /** Clamped, because a hold that overshoots by a frame must not draw a fill wider than the key. */
  const fill = $derived(Math.min(1, Math.max(0, progress)));

  /**
   * A one-character key gets a square; anything longer gets a wider box rather than a stretched
   * one. Measured off the label instead of asked for as a prop, because a caller passing
   * `wide` for `esc` and forgetting it for `ctrl` is the kind of inconsistency that only shows
   * up once both are on screen together.
   *
   * A round glyph is never wide: a face button is a circle whatever is written in it, and `A`
   * is the longest label any of them carries.
   */
  const wide = $derived(shape === 'key' && label.length > 1);
</script>

<kbd
  class="key"
  class:wide
  class:round={shape === 'round'}
  class:disabled
  class:pressed
  class:holding={fill > 0}
  style:--fill={fill}
><span class="cap">{label}</span></kbd>

<style>
  .key {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    /* Sized from the theme, not from here -- see the key-glyph block in `theme/tokens.css`.
       A surface that is read from across a room raises these; a menu leaves them alone. */
    min-width: var(--key-min);
    height: var(--key-h);
    /* The fifth token, and the last literal that was left in here. It mattered on 2026-09-04:
       `ghst_chat` is drawn entirely on its own player-adjustable `--px`, and a glyph whose cap
       height followed the chat slider while its side padding followed the *interface* slider is a
       key that changes shape when either one moves. */
    padding: 0 var(--key-pad);

    font-family: var(--font-display);
    font-variation-settings: 'wdth' 112;
    font-size: var(--key-text);
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    line-height: 1;
    text-transform: uppercase;
    color: var(--color-white);

    /* Dense, not glass: a glyph always sits inside a hint bar or a world prompt, so the thing
       behind it is a surface that has already been judged rather than the game. */
    background: var(--surface-raised);
    /* It also has to settle the scrim rather than inherit it -- a halo on a 9px glyph over an
       opaque key is smudge. `Tools/checks/glass.py` asserts this. */
    text-shadow: none;

    border: 1px solid var(--border-ambient);
    /* The one asymmetry: a darker bottom edge is what reads as a key rather than a chip. */
    border-bottom-color: rgba(0, 0, 0, 0.6);
    border-radius: var(--radius-sm);

    /* Positioned and clipped for the hold fill, which is drawn inside the key's own outline. */
    position: relative;
    overflow: hidden;

    /* Travel. Only transform and colour move, so a pressed key never reflows the row it sits in. */
    transition:
      transform var(--dur-fast) var(--ease-out),
      background-color var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out);
  }

  /* The label above the fill. A span rather than the kbd's own text so it can sit on a layer. */
  .cap {
    position: relative;
  }

  /*
   * PRESSED: the key travels one pixel down and loses the dark underside that made it look
   * pressable, because it has been pressed. The state layer brightens it the way every pressed
   * surface in this system does (`--state-pressed`), rather than inventing a colour for keys.
   */
  .pressed {
    transform: translateY(1px);
    background-image: var(--layer-pressed);
    border-color: var(--primary-glow-border);
    border-bottom-color: var(--primary-glow-border);
  }

  /*
   * THE HOLD FILL: a bar along the key's bottom edge in `--color-action`, grown from the left by
   * `--fill`. An edge and not a wash, per the rule in `theme/tokens.css`: a tinted fill behind the
   * label makes the key read as a different material, and `--color-action` is the colour the palette
   * reserves for fill animations. Where the dark underside is, because that is where a key's travel
   * is read.
   *
   * `scaleX` rather than a width, so a stream of progress updates is composited and never lays the
   * row out. Linear and short while filling -- progress arrives every ~50ms, and easing each step
   * would make the fill surge and stall -- and snapping back on the exit curve when let go.
   */
  .key::before {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 2px;
    background: var(--color-action);
    transform: scaleX(var(--fill, 0));
    transform-origin: left center;
    transition: transform var(--dur-fast) var(--ease-exit);
    pointer-events: none;
  }
  .holding::before {
    transition: transform 60ms linear;
  }

  .wide {
    min-width: var(--key-min-wide);
  }

  /**
   * A controller face button.
   *
   * A circle, and square rather than merely round: `width` is pinned to `--key-h` instead of
   * left to `min-width`, because a 50% radius on a box that is wider than it is tall is a
   * lozenge, and a lozenge is what a bumper looks like. The two must not be confusable.
   *
   * The bottom edge that makes a key look pressable is removed with it. A face button is not a
   * key -- it has no travel to suggest -- and keeping the darker underside made it read as a
   * round keycap, which is a thing that does not exist.
   */
  .round {
    width: var(--key-h);
    min-width: 0;
    padding: 0;
    border-radius: 50%;
    border-bottom-color: var(--border-ambient);
  }

  .disabled {
    opacity: 0.45;
  }

  /* Pressed on a round glyph keeps its rim: a face button has no underside to lose. */
  .round.pressed {
    border-bottom-color: var(--primary-glow-border);
  }
</style>
