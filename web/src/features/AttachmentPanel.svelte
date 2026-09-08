<script lang="ts">
  import { onDestroy } from 'svelte';
  import { inv } from '../lib/inventory.svelte';
  import { fetchNui, onNuiEvent } from '../lib/nui';
  import { items as itemDefs, locale } from '../lib/state.svelte';
  import { closeWeaponPanel, weaponPanel } from '../lib/ui.svelte';
  import Button from '../lib/Button.svelte';
  import EmptyState from '../lib/EmptyState.svelte';
  import KeyHints from '../lib/KeyHints.svelte';
  import Panel from '../lib/Panel.svelte';
  import Row from '../lib/Row.svelte';
  import Shell from '../lib/Shell.svelte';

  /**
   * WEAPON ATTACHMENTS, as a screen with the live model on it.
   *
   * `docs/ui-tdu.md` §8's row for this resource: *"weapon attachments as a screen with the LIVE
   * weapon model orbited like the ped and its points projected on"*. The design gallery drew it
   * in `screens/Inventory.svelte`, view `attachments` -- deleted 2026-09-08, `ghst_template`
   * `dcebad1`.
   *
   * What this replaced was a 340px card listing what happened to be fitted, each with an ×. It
   * could take a part off and it could not put one on, so fitting a suppressor meant closing the
   * card, finding the suppressor in the grid, and right-clicking Use — a different gesture, in a
   * different place, for the other half of one job. The screen does both from one list.
   *
   * ## The stage is a hole, and this side does not know what is in it
   *
   * CEF cannot see the renderer, so the weapon is not a picture here: `modules/weaponstage/
   * client.lua` spawns a weapon object, frames it into the rectangle this page leaves open, and
   * pushes back where each attachment point landed. The page's whole part in that is to measure
   * its own stage element, report the rect in viewport fractions, and place a dot at each pair of
   * numbers that comes back. Every gesture is the same shape: a drag is reported as a delta, and
   * Lua decides what a delta means, so the clamp lives in one place.
   *
   * ## IT IS A SCREEN, NOT A DIALOG OVER THE BAG
   *
   * It shipped as a `wide` panel centred over the two inventory panes, and that was wrong in a way
   * only the game showed. Three things followed from the panel:
   *
   *   1. **The hole was a quarter of the screen wide.** Lua solves the camera distance from the
   *      rect it is given, so a 440px stage put the camera eleven metres off a rifle — a distant,
   *      high, wide-angle shot with the model a thumbnail in the middle of it. The stage is now
   *      most of the viewport and the same arithmetic answers about two metres.
   *   2. **The model was read through the panel's own plane.** A child cannot subtract its
   *      parent's background, so the one thing on this screen that is genuinely behind the page
   *      was the one thing being looked at through two translucent layers and the inventory
   *      underneath.
   *   3. **The dots collided.** Seven labels over a 440px rectangle is a pile; over the width of
   *      the screen they are apart.
   *
   * So the panes step aside — `Inventory.svelte` hides `.wrapper` while this is up, rather than
   * unmounting it, so a bag's scroll position and search survive the trip — and what is left is
   * the weapon over the world, an ambient plate naming it, and one rail of rows on the right.
   *
   * The scrim went with the panel. A click on the empty part of this screen is a *drag to orbit*,
   * which is the one gesture the stage exists for; click-outside-to-close cannot share an element
   * with it. Escape is the way back, and the hint plate says so.
   *
   * ## Fitting and removing use the paths that were already there
   *
   * Fitting a part is `useItem` on the inventory slot holding it, which is exactly what
   * right-clicking it in the grid does (`client.lua`'s `useSlot`, the `data.component` branch);
   * removing one is `removeComponent`, which this panel already used. Neither is new, and neither
   * is optimistic: both are answered with a bare acknowledgement and the real change arrives later
   * as `refreshSlots`, so the screen watches the store for the part to move and asks Lua to
   * recompute when it does.
   */

  /** Read live from the store — see the note on `weaponPanel` in `lib/ui.svelte.ts`. */
  const item = $derived(
    weaponPanel.slot !== null ? inv.leftInventory.items[weaponPanel.slot - 1] : undefined,
  );

  const open = $derived(!!item?.name);

  /**
   * A slot that has stopped holding a weapon closes the screen.
   *
   * The screen now hides the two panes rather than sitting over them, so an item that leaves the
   * slot underneath — dropped, taken, confiscated — used to leave a dialog with nothing in it and
   * now leaves the player looking at an empty world with no bag and no way back but Escape.
   * `closeWeaponPanel` clears the slot, which unhides the panes and unmounts this.
   */
  $effect(() => {
    if (weaponPanel.slot !== null && !open) closeWeaponPanel();
  });

  /** An attachment point on this weapon, and everything that could go on it. */
  interface Option {
    name: string;
    label: string;
    /** The player-inventory slot holding one, or absent — "Not in your bag". */
    slot?: number;
    fitted: boolean;
  }

  interface Point {
    id: string;
    /** The item name of what is on it, or absent. */
    fitted?: string;
    options: Option[];
  }

  interface StagePayload {
    slot: number;
    /** Whether there is a model on the stage. False falls back to the rows alone. */
    live: boolean;
    /** Fitting and removing both refuse unless the weapon is the one in hand. */
    inHand: boolean;
    points: Point[];
  }

  let stage = $state<StagePayload | null>(null);
  let dots = $state<Array<{ id: string; x: number; y: number; visible: boolean }>>([]);

  let point = $state('');
  /** The dot under the cursor, so its name can be the one label on the stage. */
  let hovered = $state('');
  /** The candidate the Fit button would commit. `null` is the "None" row: take off what is on. */
  let choice = $state<string | null>(null);

  const current = $derived(stage?.points.find((p) => p.id === point));

  /**
   * Move to a point, and open it on what is already fitted.
   *
   * The candidate does not survive the move: a player who was looking at a scope and clicks the
   * muzzle is not still choosing the scope, and a `Fit` that committed the old one would be the
   * screen acting on something no longer on the page. Set here rather than in an effect, because
   * it is a consequence of the click and not of the value.
   */
  function selectPoint(id: string) {
    point = id;
    choice = stage?.points.find((p) => p.id === id)?.fitted ?? null;
  }

  const offStage = onNuiEvent<StagePayload>('weaponStage', (data) => {
    stage = data;

    // A point that has gone — the weapon changed underneath us — must not leave the selection
    // pointing at nothing, and the first point is the one the model is turned towards anyway.
    if (!data.points.some((p) => p.id === point)) point = data.points[0]?.id ?? '';

    // And re-open on whatever is fitted now, which is the half a refresh after a fit exists for.
    choice = data.points.find((p) => p.id === point)?.fitted ?? null;
  });

  const offPoints = onNuiEvent<{ points: typeof dots }>('weaponPoints', (data) => {
    dots = data.points;
  });

  onDestroy(() => {
    offStage();
    offPoints();
  });

  /**
   * A point's name.
   *
   * The English default is written here as well as in `locales/en.json`, which is the idiom every
   * string in this file already follows: the page renders before `init` lands and always has, and
   * the harness has no Lua to send one at all — an id showing through is the bug that reads as a
   * missing feature.
   */
  const POINT_NAMES: Record<string, string> = {
    sight: 'Scope',
    muzzle: 'Muzzle',
    barrel: 'Barrel',
    flashlight: 'Flashlight',
    grip: 'Grip',
    magazine: 'Magazine',
    skin: 'Skin',
  };

  const pointLabel = (id: string) => locale[`ui_point_${id}`] || POINT_NAMES[id] || id;

  /**
   * What is on a point, in words.
   *
   * Read out of the point's own candidate list rather than out of `items`: a component's
   * definition is not in the `init` summary — the old card had to fetch each one with
   * `getItemData` for exactly that reason — and Lua already sends a label with every candidate,
   * so the second lookup would be a second answer to a question that is already answered.
   */
  const labelOf = (p?: Point) => {
    if (!p?.fitted) return locale.ui_no_attachments || 'Nothing fitted';

    return p.options.find((o) => o.name === p.fitted)?.label || itemDefs[p.fitted]?.label || p.fitted;
  };

  /* ---- the stage rect, and the model on it -------------------------------- */

  let stageEl = $state<HTMLElement | null>(null);

  /**
   * Tell Lua where the hole is, in viewport fractions.
   *
   * A `ResizeObserver` rather than a one-shot measurement on open: the rect moves when the window
   * is resized, when the interface scale changes, and — the one that actually bites — on the frame
   * after mount, because the panel is still laying out when the effect first runs.
   */
  function report(el: HTMLElement) {
    const box = el.getBoundingClientRect();

    if (!box.width || !box.height) return;

    return {
      x: box.left / window.innerWidth,
      y: box.top / window.innerHeight,
      w: box.width / window.innerWidth,
      h: box.height / window.innerHeight,
    };
  }

  $effect(() => {
    const el = stageEl;
    const slot = weaponPanel.slot;

    if (!el || slot === null) return;

    let started = false;

    const observer = new ResizeObserver(() => {
      const rect = report(el);

      if (!rect) return;

      if (!started) {
        started = true;
        fetchNui('openWeaponStage', { slot, rect });
      } else {
        fetchNui('weaponStageRect', rect);
      }
    });

    observer.observe(el);

    return () => {
      observer.disconnect();
      fetchNui('closeWeaponStage', {});
      stage = null;
      dots = [];
    };
  });

  /**
   * What is fitted, as the store sees it — the trigger for asking Lua to recompute.
   *
   * `refreshSlots` is the only honest signal that a fit or a removal actually happened; a timer
   * after the click would either fire before the server answered or long after. Joined into a
   * string so the effect compares by value: the metadata array is replaced wholesale on every
   * refresh, so comparing the reference would re-run on every unrelated slot change.
   *
   * The first run is skipped deliberately, and the effect reads *nothing* but that string:
   * `refreshWeaponStage` answers with a `weaponStage` message, so an effect that also read `stage`
   * would be woken by its own reply and would never stop.
   */
  const fittedNow = $derived(((item?.metadata?.components as string[]) ?? []).join(','));

  let watching = false;

  $effect(() => {
    fittedNow;

    if (!watching) {
      watching = true;
      return;
    }

    fetchNui('refreshWeaponStage', {});
  });

  /* ---- orbit and zoom ----------------------------------------------------- */

  /**
   * Degrees per pixel. Slower vertically than horizontally, because the pitch is clamped to a
   * third of the arc the yaw has and matching the two makes the vertical feel like it is stuck.
   */
  const ORBIT_X = -0.4;
  const ORBIT_Y = 0.2;

  let dragging = $state(false);

  /**
   * A press that has not yet become a drag.
   *
   * The pointer is captured on the first *movement*, not on the press. Capturing on `pointerdown`
   * redirects every later event to the stage, so the click never reaches the dot that was pressed
   * — picking a point by clicking its dot silently stopped working, which reads as a dead button.
   * Three pixels is the usual slop between "clicked" and "started to drag".
   */
  const SLOP = 3;
  let pending: { x: number; y: number; id: number } | null = null;

  function onpointerdown(event: PointerEvent) {
    if (event.button !== 0) return;

    pending = { x: event.clientX, y: event.clientY, id: event.pointerId };
  }

  function onpointermove(event: PointerEvent) {
    if (!pending) return;

    if (!dragging) {
      if (Math.abs(event.clientX - pending.x) < SLOP && Math.abs(event.clientY - pending.y) < SLOP) return;

      dragging = true;
      (event.currentTarget as HTMLElement).setPointerCapture(pending.id);
    }

    fetchNui('weaponStageOrbit', {
      dx: event.movementX * ORBIT_X,
      dy: event.movementY * ORBIT_Y,
    });
  }

  function onpointerup(event: PointerEvent) {
    if (dragging) (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);

    dragging = false;
    pending = null;
  }

  // Positive delta is a scroll away, which should make the model smaller — `fill` is how much of
  // the stage it spans, so the sign flips here rather than in Lua.
  function onwheel(event: WheelEvent) {
    fetchNui('weaponStageZoom', { delta: event.deltaY > 0 ? -0.06 : 0.06 });
  }

  /* ---- fitting ------------------------------------------------------------ */

  const chosen = $derived(current?.options.find((o) => o.name === choice));

  /**
   * Whether Fit would do anything, and the words on the button.
   *
   * Three refusals, and none of them hides a row: the weapon is not in your hands, the part is not
   * in your bag, or what you picked is already on. The existing rule — Lua refuses a removal on a
   * weapon that is not in hand and says so itself — is kept as the reason on the rows rather than
   * as a row that is not drawn.
   */
  const canFit = $derived.by(() => {
    if (!stage?.inHand || !current) return false;
    if (choice === null) return !!current.fitted;

    return !!chosen && !chosen.fitted && chosen.slot !== undefined;
  });

  function fit() {
    if (!canFit || weaponPanel.slot === null || !current) return;

    if (choice === null) {
      if (current.fitted) fetchNui('removeComponent', { component: current.fitted, slot: weaponPanel.slot });
      return;
    }

    // The slot is Lua's own answer to "where is one of these", sent with the catalogue. Using it
    // is the same call the grid's right-click Use makes.
    if (chosen?.slot !== undefined) fetchNui('useItem', chosen.slot);
  }

  /** Every fitted part off, one call each — `removeComponent` is per part and always was. */
  function stripAll() {
    if (!stage?.inHand || weaponPanel.slot === null) return;

    for (const p of stage.points) {
      if (p.fitted) fetchNui('removeComponent', { component: p.fitted, slot: weaponPanel.slot });
    }
  }

  const anythingFitted = $derived(!!stage?.points.some((p) => p.fitted));

  function onkeydown(event: KeyboardEvent) {
    if (!open) return;

    // Escape also closes the inventory and Enter is not claimed by it; this is on top, so it takes
    // both first and says so.
    if (event.key === 'Escape') {
      event.stopPropagation();
      closeWeaponPanel();
    } else if (event.key === 'Enter') {
      event.stopPropagation();
      fit();
    }
  }

  /* ---- the head ----------------------------------------------------------- */

  const blurb = $derived.by(() => {
    const parts: string[] = [];
    const serial = item?.metadata?.serial as string | undefined;

    if (serial) parts.push(serial);
    if (typeof item?.metadata?.ammo === 'number') {
      parts.push(`${item.metadata.ammo} ${locale.ui_rounds || 'rounds'}`);
    }
    if (item?.durability !== undefined) {
      parts.push(`${Math.trunc(item.durability)}% ${locale.ui_condition || 'condition'}`);
    }

    return parts.join(' · ');
  });
</script>

<svelte:window {onkeydown} />

{#if open && item}
  <Shell place="fill">
    {#snippet hints()}
      <!-- Bottom left, ambient, white type — and it says what the gestures on the stage are,
           because a model you can orbit gives no other hint that you can. -->
      <div class="plate">
        <KeyHints
          tone="ambient"
          layout="inline"
          hints={[
            { key: 'lmb', does: locale.ui_orbit || 'Orbit · pick a point' },
            { key: 'wheel', does: locale.ui_zoom || 'Zoom' },
            { key: 'enter', does: locale.ui_fit || 'Fit' },
            { key: 'esc', does: locale.ui_back_to_bag || 'Back to the bag' },
          ]}
        />
      </div>
    {/snippet}

    <!--
      A `section` with a name, not a `role="dialog"`.

      It was a dialog while it sat over the two bags. It is the page now — the bags are hidden
      behind it — and the role brought a `tabindex="-1"` with it to satisfy
      `a11y_interactive_supports_focus`. That tabindex is focusable by *click*, so a drag on the
      stage made this viewport-sized element the active one, and the first alt-tab back into the
      game put Chromium into keyboard modality and drew `base.css`'s `:focus-visible` ring — two
      cyan pixels around the whole screen, out of nowhere, on a window nobody had tabbed to.
    -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <section
      class="screen"
      aria-label={locale.ui_attachments || 'Attachments'}
      oncontextmenu={(event) => event.preventDefault()}
    >
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="stage"
        bind:this={stageEl}
        class:dragging
        {onpointerdown}
        {onpointermove}
        {onpointerup}
        onpointercancel={onpointerup}
        {onwheel}
      >
        <!--
          The weapon's own name, on an ambient plate over the stage rather than in a panel header.
          It is a caption on the thing behind it, and a header would have needed a panel around it
          — which is the plane this screen has just got rid of.
        -->
        <header class="ident">
          <p class="eyebrow">{locale.ui_weapon || 'Weapon'}</p>
          <h1 class="name">
            {item.metadata?.label || itemDefs[item.name!]?.label || item.name!}
          </h1>
          {#if blurb}<p class="blurb">{blurb}</p>{/if}
        </header>

        {#if stage && !stage.live}
          <!-- The fallback the plan asked for: no model, but the rows still work. -->
          <p class="offline">{locale.ui_no_stage || 'The weapon cannot be shown here'}</p>
        {/if}

        <!--
          ONE LABEL AT A TIME. Seven captions on a weapon a metre long collide — measured in game,
          the four points that fall back to a box offset drew as a single stack of overlapping
          plates, and even with the anchors fixed a scope and a barrel are two centimetres apart on
          a pistol. The dot is always there; the name belongs to the point being pointed at.

          The rail is where the seven live as a list, with what is on each, so nothing is hidden —
          hovering a dot and reading a row are two ways to the same fact.
        -->
        {#each dots as dot (dot.id)}
          {#if dot.visible}
            {@const fitted = !!stage?.points.find((p) => p.id === dot.id)?.fitted}
            <button
              class="pt"
              class:on={dot.id === point}
              class:fitted
              style:left="{dot.x * 100}%"
              style:top="{dot.y * 100}%"
              onclick={() => selectPoint(dot.id)}
              onpointerenter={() => (hovered = dot.id)}
              onpointerleave={() => hovered === dot.id && (hovered = '')}
              aria-label={pointLabel(dot.id)}
            >
              <span class="dot"></span>
              {#if dot.id === point || dot.id === hovered}
                <span class="ptl">{pointLabel(dot.id)}</span>
              {/if}
            </button>
          {/if}
        {/each}
      </div>

      <!-- One rail, and it is the only opaque plane on the screen. Every row the old right-hand
           column had, in the panel the rest of this resource uses. -->
      <aside class="rail">
        <Panel
          eyebrow={current ? pointLabel(current.id) : locale.ui_attachments || 'Attachments'}
          title={current ? labelOf(current) : locale.ui_no_attachments || 'Nothing fitted'}
          scroll
        >
          {#if current}
            <div class="fit">
              <div class="well">
                <!-- "None" is a candidate like any other, and picking it is how a part comes off:
                     one list, one Fit button, rather than a list to put on and an × to take off. -->
                <Row
                  label={locale.ui_none || 'None'}
                  sub={locale.ui_no_attachments || 'Nothing fitted'}
                  meta={current.fitted ? undefined : locale.ui_fitted || 'Fitted'}
                  selected={choice === null}
                  onclick={() => (choice = null)}
                />
                {#each current.options as option (option.name)}
                  <Row
                    label={option.label}
                    sub={option.fitted
                      ? stage?.inHand
                        ? undefined
                        : locale.ui_attachments_hint
                      : option.slot !== undefined
                        ? locale.ui_in_bag || 'In your bag'
                        : locale.ui_not_in_bag || 'Not in your bag'}
                    meta={option.fitted ? locale.ui_fitted || 'Fitted' : undefined}
                    selected={choice === option.name}
                    disabled={!option.fitted && option.slot === undefined}
                    onclick={() => (choice = option.name)}
                  />
                {/each}
              </div>

              <div class="tight">
                <span class="caption">{locale.ui_all_points || 'All points'}</span>
                <div class="well">
                  {#each stage?.points ?? [] as p (p.id)}
                    <Row
                      label={pointLabel(p.id)}
                      meta={labelOf(p)}
                      selected={p.id === point}
                      onclick={() => selectPoint(p.id)}
                    />
                  {/each}
                </div>
              </div>
            </div>
          {:else}
            <EmptyState message={locale.ui_no_attachments || 'Nothing fitted'} />
          {/if}

          {#snippet footer()}
            <!-- One filled button, and it is the commit. Strip all is neutral beside it. -->
            <div class="acts">
              <Button disabled={!stage?.inHand || !anythingFitted} onclick={stripAll}>
                {locale.ui_strip_all || 'Strip all'}
              </Button>
              <Button variant="filled" disabled={!canFit} onclick={fit}>
                {locale.ui_fit || 'Fit'}
              </Button>
            </div>
          {/snippet}
        </Panel>
      </aside>
    </section>
  </Shell>
{/if}

<style>
  /*
   * The whole area Shell hands a `fill` page: the stage takes what is left after one rail.
   *
   * `1fr` rather than a width, because the stage's size *is* the camera's distance — Lua solves
   * one from the other — and a fixed stage would mean re-tuning the shot for every viewport.
   */
  .screen {
    display: grid;
    width: 100%;
    min-height: 0;
    gap: var(--space-5);
    grid-template-columns: minmax(0, 1fr) calc(340 * var(--ui-px));

    /* 0 everywhere but the harness — see app.css. The stage would otherwise start under the dev
       drawer, and the plate naming the weapon is the first thing the drawer covers. */
    padding-left: var(--dev-shift);
  }

  /*
   * OPEN TO THE GAME. Nothing painted at all — no border either, now that the stage is the shape
   * of the screen rather than a rectangle inside a panel that had to say where it was.
   *
   * It still claims pointer events, which is what makes the empty space a place to drag.
   */
  .stage {
    position: relative;
    min-height: 0;
    cursor: grab;
    touch-action: none;
  }

  .stage.dragging {
    cursor: grabbing;
  }

  /* Top left of the stage, out of the model's way. `--surface-ambient` is the plane that is
     allowed to be read against the world; every line on it carries `--ink-scrim`, which is the
     only reason `contrast.py` credits it. */
  .ident {
    position: absolute;
    top: 0;
    left: 0;
    max-width: calc(360 * var(--ui-px));
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-md);
    background: var(--surface-ambient);
    /* Declared on the plate rather than on each of the three lines: `text-shadow` inherits, and
       `glass.py` reads the rule that draws the surface. */
    text-shadow: var(--ink-scrim);
    /* A caption, not a control: the drag underneath it has to keep working. */
    pointer-events: none;
  }

  .eyebrow {
    margin: 0;
    color: var(--color-dim);
    font-family: var(--font-display);
    font-size: var(--text-micro);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
  }

  .name {
    margin: 0;
    color: var(--color-white);
    font-family: var(--font-display);
    font-size: var(--text-display);
    font-weight: var(--font-weight-extrabold);
  }

  .blurb {
    margin: 0;
    color: var(--color-gray);
    font-size: var(--text-meta);
  }

  .offline {
    position: absolute;
    top: 50%;
    left: 50%;
    margin: 0;
    transform: translate(-50%, -50%);
    color: var(--color-dim);
    font-size: var(--text-meta);
    text-align: center;
    text-shadow: var(--ink-scrim);
  }

  /*
   * A fixed square centred on the anchor, with the dot in the middle of it.
   *
   * The label used to be a flex sibling, which made the button as wide as the caption — and
   * `translate(-50%)` then centred *that* on the anchor, so the dot sat half a word to the left of
   * the thing it was marking, by a distance that depended on how long the word was. A label that
   * comes and goes on hover would have made the dot jump as well. So the label is taken out of the
   * flow and the square is the hit area: 28px around a 12px dot, which is a target a player can
   * hit on a moving model.
   */
  .pt {
    position: absolute;
    display: grid;
    width: calc(28 * var(--ui-px));
    height: calc(28 * var(--ui-px));
    place-items: center;
    transform: translate(-50%, -50%);
  }

  .dot {
    width: calc(12 * var(--ui-px));
    height: calc(12 * var(--ui-px));
    border: 2px solid var(--color-gray);
    border-radius: var(--radius-full);
    background: var(--color-surface);
  }

  /* A point carrying something reads as filled; the accent is reserved for the one selected. */
  .pt.fitted .dot {
    border-color: var(--color-white);
    background: var(--color-white);
  }

  .pt.on .dot {
    border-color: var(--color-primary);
    background: var(--color-primary);
    box-shadow: var(--ring-accent);
  }

  .ptl {
    position: absolute;
    left: 100%;
    padding: var(--space-0-5) var(--space-1-5);
    white-space: nowrap;
    border-radius: var(--radius-xs);
    background: var(--surface-ambient);
    /* An ambient plate is read against the game, not against the panel — the label sits over the
       stage, which is open to the world. `contrast.py` credits the scrim, so it has to be drawn. */
    text-shadow: var(--ink-scrim);
    color: var(--color-white);
    font-size: var(--text-micro);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
  }

  .pt.on .ptl {
    color: var(--color-primary);
  }

  /* A column, so the panel inside is a flex item that SHRINKS: it hugs its rows while they fit and
     is bounded by the rail once they do not, which is what hands `Panel`'s own `scroll` body
     something to scroll inside. Without the `min-height: 0` the floor is `auto` and the panel
     simply grows off the bottom of the screen, footer and all. */
  .rail {
    display: flex;
    min-height: 0;
    flex-direction: column;
  }

  .fit {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .tight {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .well {
    display: flex;
    flex-direction: column;
  }

  /* Aligned to the rows it heads. A caption that does not start where its rows start reads as a
     stray line rather than as their heading, and this one was flush against the panel's inner edge
     while every row below it was inset.

     It takes `Row`'s whole leading box rather than adding its width up: `--row-pad-x`, and the
     transparent `border-left` every row carries so the selected one can turn it into an accent
     bar. Written as a border rather than as `calc(... + 2px)` because that is what it is on a row,
     and because a raw pixel in a padding is a spacing value off the scale -- `check-tokens.mjs`
     says so and is right to. Without the border the caption lands two pixels proud of the labels,
     which is the kind of almost-aligned that reads as a mistake rather than as a choice. */
  .caption {
    padding: 0 var(--row-pad-x);
    border-left: 2px solid transparent;
    font-family: var(--font-display);
    font-size: var(--text-meta);
    letter-spacing: var(--tracking-label);
    text-transform: uppercase;
    color: var(--color-dim);
  }

  .acts {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }

  /* No ground, like every other hint plate in this resource. See CountDialog. */
  .plate {
    pointer-events: auto;
  }
</style>
