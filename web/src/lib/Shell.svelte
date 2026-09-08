<script lang="ts">
  /**
   * The persistent chrome: the overlay a panel sits in, and the four places things go around it.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * Trait 5 of `docs/ui-tdu.md`, and §2.6 called it *"the largest single item in the document and
   * the last one that should be attempted"*. It is last because it composes `Panel`,
   * `SegmentedNav` and `KeyHints`, and building it before those existed would have meant inventing
   * all three inside it.
   *
   * ## It is not Solar Crown's shell, and that is deliberate
   *
   * The reference's chrome is *identity chip left, segmented nav centre, currency right, hints
   * bottom* — and `IdentityChip` in this same folder is a faithful copy of it: level, name,
   * vehicle, rating. **It has no callers and it is right not to have any.** That is a racing
   * game's chrome, and this tree's panels are a bank, a wardrobe, a clothes shop, a garage and an
   * emote list. A vehicle rating on an ATM is a costume.
   *
   * So this owns *positions* and the caller owns *contents*. That is the one kind of hole a
   * component may have in the middle: `ChoiceRow`'s header is right that a slot for anything
   * settles nothing, but a shell's entire job is arranging things it does not own, and the
   * disagreement it prevents is **where the chrome goes**, not what is in it.
   *
   * ## What it actually retires
   *
   * Six resources centre a panel over the game — banking, crypto, customs, emotes, phone, skills —
   * and every one re-derives the same four things:
   *
   *   1. `position: fixed; inset: 0` with **`pointer-events: none` on the frame and `auto` on each
   *      surface**, so the gaps belong to the game. Get this wrong and a full-screen overlay eats
   *      every click in the world behind it.
   *   2. Centring, and the `min-height: 0` chain that lets a tall panel scroll instead of growing.
   *   3. A scrim.
   *   4. A window `keydown` listener for Escape, added and removed in a lifecycle.
   *
   * None of those is interesting and all four are silent when wrong.
   *
   * ## The blur is Lua's, and this must never attempt it
   *
   * `backdrop-filter` cannot blur the game: CEF paints the page and the engine composites it over
   * the already-rendered frame, so there is nothing behind this element inside the browser layer.
   * `lib.screenBlur(show, ms)` is the real thing and it **counts holders**, because the native does
   * not and ten resources sharing one flag is a blur that never lifts. A CSS blur here would be a
   * no-op that looks like a decision.
   *
   * The `scrim` below is a plain dim, which does work — it darkens the page's own ground, not the
   * game's.
   */
  import type { Snippet } from 'svelte';
  import { onMount } from 'svelte';

  interface Props {
    /**
     * Where the content sits.
     *
     * `centre` is the common case and the one six resources hand-roll. `fill` hands the whole area
     * over and is for a page that lays out its own columns — `ghst_appearance`'s four-corner shop
     * keeps its layout and takes only the chrome rails, which is what `fill` is for.
     */
    place?: 'centre' | 'start' | 'end' | 'fill';
    /**
     * Dim the ground behind the content. Not a blur — see the header.
     *
     * `true` is the full `--scrim`, for a panel with nothing else darkening the ground behind it.
     *
     * `'light'` is for a panel that takes NUI focus and never blurs, so the world behind it is
     * live. `ghst_admin` has one of each and is the reason this is not a boolean: its palette
     * blurs and its build panel does not, and that panel had written its own
     * `rgba(10, 10, 10, 0.35)` by hand — *"lighter than the palette's scrim: this panel is read
     * against the world behind it."* The reason survived checking, so the number became
     * `--scrim-light` rather than being argued away.
     *
     * `'clear'` is a veil that catches the click and paints nothing, for a panel the *game* has
     * already dimmed. **`lib.screenBlur` is itself a dim** — a blurred plate is darker and flatter
     * than the scene it replaced — so a `--scrim` on top of one is the second dim of the same
     * pixels, and the translucent `--surface-panel` sitting on it goes to near-black. `ghst_banking`
     * said it first and in as many words: *"a dim over a blur reads as a loading screen."*
     *
     * That is also the correction to what this doc used to claim, which was that `true` is right
     * *because* the blur is up — *"dimming it hard costs nothing"*. It costs the panel. Five of
     * the six resources that blur for a modal panel had quietly agreed and passed no scrim at all;
     * `ghst_emotes` passed `true`, and its menu read visibly darker than every other panel in the
     * tree until 2026-09-04. It could not simply drop the prop, because the veil is also its
     * click-out target — which is the hole this value fills.
     */
    scrim?: boolean | 'light' | 'clear';
    /** Top left: who or where you are. A venue plate, an account, an `IdentityChip`. */
    identity?: Snippet;
    /** Top centre: the section strip, usually a `SegmentedNav`. */
    nav?: Snippet;
    /** Top right: the number that is always true here — money, a clock, a count. */
    aside?: Snippet;
    /** Bottom: a `KeyHints`. Drawn across the full width, under everything. */
    hints?: Snippet;
    children: Snippet;
    /**
     * A click on the scrim, reported rather than handled. Ignored without a `scrim`.
     *
     * ## It must never be the only way out
     *
     * A scrim is not focusable and has no keyboard equivalent, so a page whose *only* dismissal is
     * a click on it is a page a keyboard cannot leave. Every caller of this must also offer an
     * Escape or a close button, and both of the ones that exist do — `ghst_multichar`'s menu
     * panels have an X in the header, deliberately, *because* that screen has no Escape at all:
     * *"a player who dismisses the whole character screen is frozen in a tutorial session with no
     * UI and no way to pick anyone."*
     *
     * ## Why it is a prop at all
     *
     * The scrim shipped as a pseudo-element, which cannot take events — and two resources lost a
     * real gesture to that. `ghst_emotes` had `<div class="scrim" onclick={close}>` and gave it up
     * on adoption; `ghst_multichar` could not have adopted at all, because clicking out **is** how
     * its panels close.
     *
     * So the scrim is a real element now, and the pseudo-element note it replaced was right about
     * the one thing that matters: it is painted *under* the content and claims its own clicks, so
     * a panel sitting on it is unaffected and the gaps around that panel are the dismissal.
     */
    onscrim?: () => void;
    /**
     * Escape, reported rather than handled.
     *
     * The shell owns the listener because adding and removing one correctly is the boring half;
     * it does not own the *decision*, because that differs and the difference matters —
     * `ghst_appearance` backs out one level of a tree before it closes, and a shell that closed on
     * the first press would throw away a player's place in a wardrobe.
     */
    onescape?: () => void;
  }

  let {
    place = 'centre',
    scrim = false,
    identity,
    nav,
    aside,
    hints,
    children,
    onscrim,
    onescape,
  }: Props = $props();

  onMount(() => {
    if (!onescape) return;

    /* On `window`, not on the shell: with NUI focus captured the key reaches the browser, and a
       player who has just clicked inside a grid has focus somewhere that is not this element. */
    const key = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;

      event.preventDefault();
      onescape();
    };

    window.addEventListener('keydown', key);

    return () => window.removeEventListener('keydown', key);
  });

  /** Only drawn when something is in it, so an empty rail costs no height. */
  const hasChrome = $derived(Boolean(identity || nav || aside));
</script>

<div
  class="shell"
  class:scrim={Boolean(scrim)}
  class:light={scrim === 'light'}
  class:clear={scrim === 'clear'}
>
  <!--
    A real element rather than a pseudo-element, so it can carry the click. `role="presentation"`
    is honest here in a way it was not in the markup this replaces: the gesture is redundant with
    a close button or Escape every time — see `onscrim` — so there is nothing here that assistive
    technology is being denied.
  -->
  {#if scrim}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div class="veil" role="presentation" onclick={onscrim}></div>
  {/if}

  {#if hasChrome}
    <header class="chrome">
      <div class="side">{#if identity}{@render identity()}{/if}</div>
      <div class="mid">{#if nav}{@render nav()}{/if}</div>
      <div class="side end">{#if aside}{@render aside()}{/if}</div>
    </header>
  {/if}

  <div class="content {place}">{@render children()}</div>

  {#if hints}
    <footer class="feet">{@render hints()}</footer>
  {/if}
</div>

<style>
  /*
   * THE FRAME CLAIMS NOTHING. `pointer-events: none` here and `auto` on each surface, so the gaps
   * between them belong to the game — a player dragging to orbit a character, or clicking a door
   * behind a corner panel, must be able to reach through.
   *
   * This is the single most-repeated and most-silently-wrong thing in the six resources this
   * replaces: an overlay that claims its whole area eats every click in the world behind it, and
   * nothing on screen says so.
   */
  .shell {
    position: fixed;
    inset: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    /*
     * `--edge-x` / `--edge-y`, NOT `--space-4`, and the token's own note says why in as many
     * words: this is *"a measurement of the FRAME, not a size of type, so it must not answer the
     * player's interface-size preference -- an inset that moved with `uiScale` would push the HUD
     * off a screen it was fitting a moment earlier."* `--space-4` is
     * `calc(16 * var(--ui-px) + var(--density-step))` and does exactly that.
     *
     * It also happens to be the number eight resources already hold off the frame, so a shell
     * placing a panel at the right edge lands where `ghst_shops` and `ghst_devtools` already put
     * theirs by hand. Found 2026-09-04 while adopting this in `ghst_shops`, whose panel was
     * `right: var(--edge-x)`.
     */
    padding: var(--edge-y) var(--edge-x);
    pointer-events: none;
  }

  /*
   * A plain dim, UNDER everything, and an element of its own rather than a background on
   * `.shell` — which would sit under the children correctly but be painted at
   * `pointer-events: none`, and a scrim that cannot be clicked cannot be a
   * click-outside-to-close target.
   *
   * It was a pseudo-element until 2026-09-04, which had the same property and one fewer node.
   * The reason it is not any more is that a pseudo-element cannot carry a handler either, so
   * "whoever wants one later" could never have had one — `ghst_emotes` gave a working gesture up
   * on adoption and `ghst_multichar`, whose panels close *only* this way, could not have adopted
   * at all. See `onscrim`.
   */
  .shell.scrim .veil {
    position: absolute;
    background: var(--scrim);
    inset: 0;
    pointer-events: auto;

    /*
     * UNDER THE CONTENT, AND THE NEGATIVE IS LOAD-BEARING.
     *
     * This file's header claimed the veil "is painted *under* the content and claims its own
     * clicks, so a panel sitting on it is unaffected". It was not. The veil is POSITIONED and
     * `.chrome`, `.content` and `.feet` are ordinary in-flow flex items, and CSS paints positioned
     * descendants (even at `z-index: auto`) above non-positioned block-level ones whatever the DOM
     * order says. So a full-screen transparent div sat on top of every panel this component has
     * ever framed, and swallowed every click and every wheel event aimed at one.
     *
     * `z-index: 0` does not fix it -- that still paints in the positioned pass. Only a negative
     * index moves it into the pass BEFORE in-flow block content, which is what "under" has to mean.
     * `.shell` is `position: fixed` and therefore its own stacking context, so the -1 is contained:
     * the scrim cannot fall behind the page, and it still catches the clicks in the gaps around the
     * content, which is what `onscrim` is for.
     *
     * Found 2026-09-08 in the template's kit reference -- an unclickable tab strip over an
     * unscrollable panel, both from this one line. It was not new. Two callers had already worked
     * around it locally without naming it: `ox_inventory`'s `CountDialog` carries
     * `position: relative; z-index: 80` on its plate and its `AttachmentPanel` carried a `90`,
     * which is exactly the shape of a fix applied to the symptom. The two that had not --
     * `ghst_admin`'s build panel and its command palette, both `scrim="light"` over an unpositioned
     * wrapper -- could not be clicked at all.
     */
    z-index: -1;

    /*
     * A SCRIM ARRIVES; IT DOES NOT APPEAR. A dim that cuts in on one frame reads as the page
     * flickering, and every resource that hand-rolled one had reached the same conclusion --
     * `ghst_multichar`'s carried `ghst-fade-in` and all four of `ox_inventory`'s dialogs carry a
     * 120ms `transition:fade`. Adopting this component dropped `ghst_multichar`'s, which is how
     * the omission was noticed.
     *
     * The keyframe is declared HERE rather than reached for in the theme, and that is the point:
     * `ghst-fade-in` exists in three of the eleven `motion.css` files in the tree, and half the
     * resources have no `motion.css` at all. A shared component cannot depend on a keyframe its
     * host may not have. Svelte scopes this one to this file, so it travels with it.
     */
    animation: shell-veil-in var(--dur-base) var(--ease-out) both;
  }

  @keyframes shell-veil-in {
    from {
      opacity: 0;
    }
  }

  /* `ghst_prefs` owns the flag and writes it on the document element. A scrim is the least
     interesting thing on a screen to animate and the first one somebody who asked for stillness
     will notice. */
  :global(:root[data-reduce-motion]) .shell.scrim .veil {
    animation: none;
  }

  .shell.scrim.light .veil {
    background: var(--scrim-light);
  }

  /*
   * NOTHING TO PAINT, SO NOTHING TO FADE IN EITHER. The `both` fill on the animation above would
   * otherwise hold this at `opacity: 0` for a frame and then at 1 — invisible either way, but a
   * compositor layer for a transparent rectangle is a layer for nothing.
   *
   * It still claims its pixels: `pointer-events: auto` is on `.veil` unconditionally, and that is
   * the whole reason this value exists rather than the caller passing no scrim at all.
   */
  .shell.scrim.clear .veil {
    animation: none;
    background: none;
  }

  /*
   * Three cells, and the middle one is centred on the SCREEN rather than on what is left over.
   * `1fr auto 1fr` puts the nav in the true centre whatever the identity and the aside weigh —
   * with `space-between` a long venue name would shove the section strip sideways, and a strip
   * that moves when the title changes reads as two different layouts.
   */
  .chrome {
    display: grid;
    flex: none;
    align-items: start;
    gap: var(--space-4);
    grid-template-columns: 1fr auto 1fr;
  }

  .side {
    display: flex;
    min-width: 0;
    align-items: flex-start;
    pointer-events: auto;
  }

  .side.end {
    justify-content: flex-end;
  }

  .mid {
    display: flex;
    justify-content: center;
    pointer-events: auto;
  }

  /* `min-height: 0`, so a panel taller than the screen scrolls inside itself rather than growing
     the shell and pushing the hints off the bottom. A flex child's `auto` minimum is the floor
     that turns "scrolls" into "grows", and it is invisible until the content is long. */
  .content {
    display: flex;
    min-height: 0;
    flex: 1;
  }

  .content.centre {
    align-items: center;
    justify-content: center;
  }

  .content.start {
    align-items: stretch;
    justify-content: flex-start;
  }

  .content.end {
    align-items: stretch;
    justify-content: flex-end;
  }

  /* The whole area, for a page that arranges its own columns. */
  .content.fill {
    align-items: stretch;
  }

  .content.fill > :global(*) {
    flex: 1;
    min-width: 0;
  }

  /*
   * The content claims its own pixels rather than the cell claiming them, so the space *around* a
   * centred panel stays the game's. `> :global(*)` is the only way to reach a child a slot put
   * there, and it is narrow on purpose — one property, on direct children only.
   */
  .content > :global(*) {
    pointer-events: auto;
  }

  .feet {
    display: flex;
    flex: none;
    justify-content: space-between;
    pointer-events: auto;
  }
</style>
