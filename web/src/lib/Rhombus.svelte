<script lang="ts">
  /**
   * The rhombus: a bullet, a tier mark, a "you are here".
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * ## This is the one hand-drawn shape in the tree, and that needs saying out loud
   *
   * The convention everywhere else is absolute: **icons come through `lib/icons.ts` and are never
   * hand-drawn SVG paths.** It exists because a hand-drawn glyph has no stroke weight discipline,
   * no shared viewBox and no way to be swapped — and because the moment one exists, the next one
   * is easier to justify.
   *
   * A rhombus is not in Lucide. `docs/ui-tdu.md` §2.6 anticipated exactly this — *"a rhombus is not
   * in Lucide, so this is the first legitimate exception and needs that convention amended rather
   * than quietly ignored"* — so the amendment is here, in the file that takes it:
   *
   * > **The exception is a shape that is a *mark* rather than an icon.** An icon depicts something
   * > and belongs in a set with a consistent weight; a mark is geometry the brand repeats at every
   * > scale, and Lucide has no opinion about it because it is not a picture of anything. One file,
   * > one shape, no `d` attribute — a rotated square, which is a `<rect>` and a transform.
   *
   * Written as a rotated square rather than a `<path>` on purpose: there is no path data to get
   * subtly wrong, it scales without a viewBox argument, and the next person can see at a glance
   * that it is a square turned 45° rather than four hand-typed coordinates.
   *
   * ## Sized in `em`
   *
   * So a bullet inherits the size of the text it sits beside and a tier mark inherits its badge's.
   * A pixel size would need a prop at every call site and would drift from the type it accompanies
   * the moment the interface scale moved.
   */
  interface Props {
    /**
     * `solid` is a bullet or a mark; `hollow` is the same shape as an outline, for a state that is
     * *available* rather than *taken* — an unvisited step, an empty slot.
     */
    variant?: 'solid' | 'hollow';
    /** Multiplier on the inherited text size. 1 is a bullet beside body text. */
    scale?: number;
  }

  let { variant = 'solid', scale = 1 }: Props = $props();
</script>

<span
  class="rhombus {variant}"
  style={`--rhombus-size: ${scale}em`}
  aria-hidden="true"
></span>

<style>
  /*
   * A CSS square with a transform, not an SVG at all.
   *
   * The header argues for a `<rect>` and a transform over a `<path>`; taken one step further,
   * there is no reason for the SVG element either. A rotated span costs no markup, inherits
   * `currentColor` for free, and cannot carry a viewBox that disagrees with the icon set's.
   *
   * `rotate` rather than `transform: rotate()` — the standalone property works in this CEF build
   * (measured: Chromium 103 with experimental features on, so the real line is ~108) and leaves
   * `transform` free for anything a caller composes on top.
   */
  .rhombus {
    display: inline-block;
    width: var(--rhombus-size);
    height: var(--rhombus-size);
    flex: none;
    rotate: 45deg;
    /* Not a full corner-round: a rhombus with sharp points is the reference's, and a hairline
       radius only stops the tips aliasing into grey specks at small sizes. */
    border-radius: var(--radius-xs);
    background: currentColor;
  }

  .rhombus.hollow {
    border: 1px solid currentColor;
    background: none;
  }
</style>
