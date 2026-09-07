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
   * Change it in `Tools/ghst_template/web/src/lib/KeyGlyph.svelte`.
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
  }

  let { label, shape = 'key', disabled = false }: Props = $props();

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

<kbd class="key" class:wide class:round={shape === 'round'} class:disabled>{label}</kbd>

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
</style>
