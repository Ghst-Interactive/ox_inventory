<script lang="ts">
  /**
   * The surface itself: an eyebrow over a title, whatever the panel is for, and a footer.
   *
   * ONE FILE WITH COPIES, like every shared component here, and **authored in `ox_lib`** so it can
   * reach the GPL resources *and* the LGPL fork — see `Row.svelte`'s header for the licence
   * routing, which is the reason `Button` and `ChoiceRow` can never come back the other way.
   *
   * ## What it is derived from
   *
   * Trait 5 of `docs/ui-tdu.md`: *"every panel invents its own frame"*. Measured across the tree on
   * 2026-09-04 — 39 `head` blocks, 24 `title`, 18 `sub`, 10 `close`, 5 `eyebrow`, 3 `tier`,
   * 3 `blurb` — and the shape underneath all of them is the same one every time: **a small tracked
   * label above a Title Case name, an optional line of prose under it, and a cluster of icon
   * actions pinned right.**
   *
   * `ghst_appearance`'s `Brand.svelte` is the clearest statement of it and its comment says why the
   * eyebrow is not optional decoration: *"something has to sit above the name or it reads as a
   * heading with a gap over it."*
   *
   * ## What it deliberately does not decide
   *
   * **Where the panel is and how wide it is.** Those are the page's, and a component that took
   * them would be the shell rather than a panel — the shell is a separate item in §6 and is built
   * *on* this. So there is no `position`, no width and no `max-height` here; the host places it
   * and this fills what it is given.
   *
   * **Whether it scrolls is asked for, not assumed.** The body supplies the `min-height: 0` chain
   * and, by default, no `overflow`: a body that forced `overflow-y: auto` on every caller would
   * break the ones whose body is a multi-column layout with scrollers of its own (`ghst_skills`
   * says so at its own scroller). But three mockups in the design gallery grew off the screen
   * before their authors added the one line, so the one line is a prop now: `scroll` makes the
   * body the scroller. Decided once, 2026-09-05, after the gallery found it three times.
   *
   * That boundary is not theoretical. `ghst_appearance` carried `max-height: 52vh` on its panel
   * body for weeks after the layout that needed it was deleted, and the symptom was a wardrobe
   * abandoning the bottom third of its own column. A panel that cannot express a height cannot
   * inherit a stale one.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    /**
     * The small tracked label above the title — a tier, a category, a section.
     *
     * Optional, but the callers that omit it should usually pass something: a title with nothing
     * over it reads as a heading with a gap above it rather than as the top of a panel.
     *
     * ## When one line is right, and this component is the wrong one
     *
     * **An eyebrow names the kind and a title names the instance.** `ghst_shops` is `Discount`
     * over `Binco`, `ghst_admin`'s build panel is `Build` over `Coordinates`, `ghst_garages` is
     * `Storage` over `Eclipse Boulevard`. Each pair is two different facts.
     *
     * A panel with only *one* of those has one line, and drawing it as a pair means inventing the
     * other. `ghst_hud`'s `/hud` rail is the case: its heading is the word `HUD`, set at eyebrow
     * weight, and its own note is right that *"the treatment is what makes it a heading"* — a
     * `Ghst` stacked over it would spend two lines saying one thing on a 296px rail. `ox_lib`'s
     * `ContextMenu` heading is the same shape for the same reason.
     *
     * Those are not callers this component should acquire by growing a variant. They are small
     * surfaces whose whole header is a label, and a label is one element.
     */
    eyebrow?: string;
    title: string;
    /** A line of prose under the title. A shop's tagline, a screen's one-line explanation. */
    blurb?: string;
    /**
     * A small square plate to the LEFT of the title — a letterform, a venue icon, a logo.
     *
     * Measured rather than invented. Exactly two panels in the tree lead with one, `ghst_banking`
     * and `ghst_crypto`, and the two are almost the same file: 34px, `place-items: center`, a
     * `--primary-glow` fill inside a `--primary-glow-border` hairline, ink in `--color-primary`.
     * Two authors reached that independently and disagreed on **one** property — the corner, `md`
     * against `full`.
     *
     * That disagreement is why the plate is drawn here and only its *contents* are the caller's.
     * A slot is the right shape because the two contents are genuinely different in kind (an
     * invented coin's initial; a bank's Lucide glyph, and `ghst_crypto`'s note is right that a
     * generic currency icon would be claiming the coin is a real one) — but the disc around them
     * is not a difference, it is a drift.
     *
     * `--radius-md` settles the corner, matching the panel it sits inside. `ghst_crypto`'s
     * `--radius-full` had no note defending it; its comment argues for the letterform, not for
     * the circle, and the tree's corner scale went square for panels and rows with a control as
     * the stated exception. A plate is not a control.
     */
    mark?: Snippet;
    /** Icon buttons pinned to the right of the title row — undo, redo, close. */
    actions?: Snippet;
    /**
     * Anything under the header and above the footer.
     *
     * **Optional, because a header-only panel is a real thing.** `ghst_appearance`'s `Brand` is
     * exactly one — a venue plate with a tier, a name, a tagline and three icon buttons, and no
     * body at all — and so is anything used as an identity plate in `Shell`'s left rail. Requiring
     * a body would have meant those callers passing an empty snippet, which is a lie that also
     * draws a border.
     */
    children?: Snippet;
    /** Pinned to the bottom and never scrolled with the body — a till, a pair of verbs. */
    footer?: Snippet;
    /** The body is the scroller. For a single column of rows; not for a body with its own. */
    scroll?: boolean;
  }

  let { eyebrow, title, blurb, mark, actions, children, footer, scroll = false }: Props = $props();
</script>

<section class="panel">
  <header class="head">
    <div class="top">
      {#if mark}<span class="mark">{@render mark()}</span>{/if}

      <div class="who">
        {#if eyebrow}<p class="eyebrow">{eyebrow}</p>{/if}
        <h2 class="title">{title}</h2>
      </div>

      {#if actions}
        <div class="acts">{@render actions()}</div>
      {/if}
    </div>

    {#if blurb}<p class="blurb">{blurb}</p>{/if}
  </header>

  <!-- The scroller, and the only element here with `min-height: 0`. A flex child defaults to
       `min-height: auto`, which is the floor that quietly turns "scrolls" into "grows" and pushes
       the footer off the bottom. -->
  {#if children}
    <div class="body" class:scroll>{@render children()}</div>
  {/if}

  {#if footer}
    <footer class="foot">{@render footer()}</footer>
  {/if}
</section>

<style>
  /*
   * Square, bordered, opaque. `--surface-panel` is 0.97 rather than the 0.84 it shipped at, and
   * that correction is worth knowing about here of all files: a focused panel is a *surface*, and
   * the game showing through it made an ATM read as a pane of glass with an ATM behind it.
   * `--surface-ambient` is the tier that still shows the world, and it is for things that float on
   * the scene rather than things you are reading.
   *
   * No width, no position, no height. See the header.
   */
  .panel {
    display: flex;
    min-height: 0;
    flex-direction: column;
    /*
     * **FILLS WHAT IT IS GIVEN, which this file claimed and did not do.** The header says the host
     * owns where the panel is and how wide it is and that this fills the result -- and a flex item
     * defaults to `flex: 0 1 auto`, so in a flex *row* it sized to its own content and left the
     * rest of the frame empty.
     *
     * Every caller until 2026-09-04 hid it: they are 420-480px frames whose content is wider than
     * the box, so the item shrank to fit and looked correct. `ghst_garages`' 1040px panel is the
     * first that is wider than its content, and it drew a 500px card floating in the left half of
     * its own frame -- which reads as a washed-out, timid panel rather than as a layout fault,
     * because nothing about it is *wrong*, there is just less of it than there should be.
     *
     * `width`, not `flex: 1`: this must not change anything on the block axis. A header-only panel
     * in a column has a height it means, and growing it would be a border round a lot of nothing.
     */
    width: 100%;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--surface-panel);
    color: var(--color-gray);
    text-shadow: var(--ink-scrim);
  }

  .head {
    display: flex;
    flex: none;
    flex-direction: column;
    gap: var(--space-1);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--color-border);
  }

  /* A header-only panel has nothing to be separated FROM, and a rule along its bottom edge inside
     a bordered box draws two hairlines a pixel apart. `:only-child` rather than a prop, because
     the condition is structural and the markup already states it. */
  .head:only-child {
    border-bottom: 0;
  }

  .top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-3);
  }

  /* The plate. See the `mark` prop for why the disc is the component's and its contents are not.
     Sized in `--ui-px` rather than the raw `34px` both callers wrote: it is a plate around a
     letterform, so it answers the player's interface size for the same reason the letterform
     does. */
  .mark {
    display: grid;
    flex: none;
    width: calc(34 * var(--ui-px));
    height: calc(34 * var(--ui-px));
    place-items: center;
    border: 1px solid var(--primary-glow-border);
    border-radius: var(--radius-md);
    background: var(--primary-glow);
    color: var(--color-primary);
    font-family: var(--font-display);
    font-size: var(--text-subheading);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
  }

  /* `flex: 1` rather than leaning on `space-between`, which lines two children up correctly and
     puts a third in the MIDDLE — so the day a panel grew a leading plate the title would have
     drifted off the mark it belongs to. Both hand-rolled headers already wrote it. */
  .who {
    display: flex;
    min-width: 0;
    flex: 1;
    flex-direction: column;
  }

  /*
   * ALL-CAPS AND TRACKED OUT, on the display face — trait 4, and the habit this tree already had
   * before Solar Crown was picked as a reference. At this size only the width axis makes it read
   * as a label rather than as small body text.
   */
  .eyebrow {
    /*
     * Dim, unless the caller says otherwise — the one themeable hook on this component.
     *
     * An eyebrow is a *label* almost everywhere and dim is right for a label. `ghst_shops`' is not
     * a label: it is the shop's **brand** line, coloured from `shop.accent` so a surveyed
     * storefront can wear its own colour, and that field's only reader in the whole resource is
     * that one rule. Making the eyebrow unconditionally dim would have quietly turned a piece of
     * Lua config into dead data.
     *
     * A custom property rather than a prop, deliberately: it is a colour a *host* sets on the
     * surrounding frame, it needs no TypeScript, and a component with a `colour` prop invites
     * every caller to have an opinion. The default is the answer for everyone else.
     */
    color: var(--panel-eyebrow, var(--color-dim));
    font-family: var(--font-display);
    font-size: var(--text-label);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-bold);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
  }

  /* Title Case, not caps. The pair is the trait: a tracked-out label over a name that is simply a
     name. Two caps lines would be a masthead. */
  .title {
    overflow: hidden;
    color: var(--color-white);
    font-family: var(--font-display);
    font-size: var(--text-subheading);
    font-variation-settings: 'wdth' 112;
    font-weight: var(--font-weight-extrabold);
    letter-spacing: var(--tracking-display);
    line-height: var(--leading-tight);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .blurb {
    color: var(--color-dim);
    font-size: var(--text-meta);
  }

  .acts {
    display: flex;
    flex: none;
    align-items: center;
    gap: var(--space-1);
  }

  .body {
    display: flex;
    min-height: 0;
    flex: 1;
    flex-direction: column;
  }
  .body.scroll {
    overflow-y: auto;
  }

  .foot {
    display: flex;
    flex: none;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    border-top: 1px solid var(--color-border);
  }
</style>
