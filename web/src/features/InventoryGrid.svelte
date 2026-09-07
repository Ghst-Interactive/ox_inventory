<script lang="ts">
  import { categoryOf, categoryRank } from '../lib/categories';
  import { getTotalWeight, isSlotWithItem } from '../lib/helpers';
  import { inv } from '../lib/inventory.svelte';
  import { fetchNui } from '../lib/nui';
  import { items as itemDefs, locale } from '../lib/state.svelte';
  import { InventoryType, type Inventory, type Slot } from '../typings';
  import { tidy } from '../lib/tidy';
  import EmptyState from '../lib/EmptyState.svelte';
  import Field from '../lib/Field.svelte';
  import Icon from '../lib/Icon.svelte';
  import Panel from '../lib/Panel.svelte';
  import Bar from '../lib/Bar.svelte';
  import Button from '../lib/Button.svelte';
  import { ArrowDownAZ, Backpack, Info, Search, Settings, X } from '../lib/icons';
  import UsefulControls from './UsefulControls.svelte';
  import SettingsPanel from './SettingsPanel.svelte';
  import InventorySlot from './InventorySlot.svelte';

  let {
    inventory,
    container = false,
  }: {
    inventory: Inventory;
    /**
     * This is the bag pane, open alongside the other two rather than in place of one — so
     * it is the only pane that can be dismissed on its own, and needs a way to say so.
     */
    container?: boolean;
  } = $props();

  /**
   * A pane of slots.
   *
   * PAGINATION IS LOAD-BEARING. A police locker is seventy slots and a drop can be fifty;
   * rendering the lot on open is what the 30-at-a-time window exists to avoid. It is kept
   * as-is rather than swapped for a virtual-list library — this already works, and a
   * virtual list would have to be taught about the drag layer's hit testing.
   */
  const PAGE_SIZE = 30;

  /** Below this there is nothing to search, and the field is only clutter. */
  const SEARCH_THRESHOLD = 20;

  let page = $state(0);
  let query = $state('');
  let chosen = $state<string | null>(null);

  /**
   * THE FIELD IS BEHIND A BUTTON NOW.
   *
   * It was drawn permanently above the grid, in both panes at once, whenever a pane held more than
   * `SEARCH_THRESHOLD` slots -- which is nearly always. Two full-width fields, each with a label,
   * a glyph and a gap, standing open for something a player does occasionally: together they cost
   * more of the pane than the chips and the carry bar, and both of those are read every time the
   * inventory opens.
   *
   * The header row already exists and already holds this pane's verbs, so the magnifier goes there
   * beside Backpack and Tidy. Opening focuses the field; closing clears the query, because a
   * filter that is narrowing a pane from behind a closed door is the same trap as filtering
   * instead of dimming -- see the note over `matches`.
   */
  let searching = $state(false);
  let field = $state<HTMLElement | null>(null);

  function toggleSearch() {
    searching = !searching;
    if (!searching) return void (query = '');

    // The input lives inside `Field`, which exposes no ref; reaching for the wrapper's first
    // input is enough and does not depend on that component's internals.
    queueMicrotask(() => field?.querySelector('input')?.focus());
  }

  /** Global, so only on your own pane: one inventory is open and these two panels are about it. */
  let helpOpen = $state(false);
  let settingsOpen = $state(false);
  const ownPane = $derived(
    inventory.type === InventoryType.PLAYER && inventory.id === inv.leftInventory.id,
  );

  const searchable = $derived(inventory.slots > SEARCH_THRESHOLD);
  const needle = $derived(query.trim().toLowerCase());

  /**
   * How many rows of the bag to show.
   *
   * The other panes are a fixed five rows so that two side by side are the same height
   * (see .slot-grid in app.css). A bag is not beside anything — it hangs under the
   * player's own pane — so five rows of it would push the pair past the bottom of the
   * screen on a 1080p client. It gets its own count instead: as many rows as it has, up
   * to four, and it scrolls beyond that.
   *
   * --grid-cols is the column count the CSS lays out with; it is a constant, and the
   * arithmetic to turn slots into rows has to happen here rather than in the stylesheet.
   */
  const GRID_COLS = 5;
  const MAX_CONTAINER_ROWS = 4;

  const gridRows = $derived(
    container ? Math.min(Math.ceil(inventory.slots / GRID_COLS), MAX_CONTAINER_ROWS) : null,
  );

  /**
   * The bag the player is carrying, if any — the button in this pane's header opens it.
   *
   * Only their own pane offers it, and only the first container found: with two bags on
   * you the button is a shortcut to one of them, and using the item itself still opens
   * whichever you meant. A bag inside a bag is impossible (onDrop refuses it), so the
   * pane's own items are the whole search.
   */
  const bagSlot = $derived(
    inventory.type === InventoryType.PLAYER
      ? inventory.items.find((slot) => slot.metadata?.container !== undefined)
      : undefined,
  );

  const bagOpen = $derived(!!inv.containerInventory);

  const bagLabel = $derived(
    bagSlot ? (bagSlot.metadata?.label ?? itemDefs[bagSlot.name!]?.label ?? bagSlot.name) : '',
  );

  /**
   * Toggling is asymmetric on purpose. Closing goes through `closeContainer`, which shuts
   * whichever bag is open; opening names a slot. With one bag the two are the same thing,
   * and with two the button never has to guess which one you meant to close.
   */
  const toggleBag = () =>
    bagOpen ? fetchNui('closeContainer') : fetchNui('openContainer', bagSlot!.slot);

  /**
   * Chips are built from what is actually in the pane, not from the full category list.
   *
   * That is what keeps the row short: eleven categories exist, a real inventory holds
   * three or four. It also means a chip never offers a filter that would empty the pane.
   */
  const present = $derived.by(() => {
    const counts = new Map<string, number>();

    for (const slot of inventory.items) {
      const category = categoryOf(slot);
      if (category) counts.set(category, (counts.get(category) ?? 0) + 1);
    }

    return [...counts.entries()].sort(
      ([a], [b]) => categoryRank(a) - categoryRank(b) || a.localeCompare(b),
    );
  });

  // One chip is not a filter, it is a label — and the same threshold as the search keeps a
  // six-slot crafting bench free of both.
  const chipped = $derived(inventory.slots > SEARCH_THRESHOLD && present.length > 1);

  /** What `All` counts: things in the pane, not squares. Wrapped rather than passed by name,
      for the `strict`-flag reason spelled out over `filled` below. */
  const itemCount = $derived(inventory.items.filter((slot) => isSlotWithItem(slot)).length);

  const chipLabel = (name: string) =>
    locale[`ui_cat_${name}`] || name.charAt(0).toUpperCase() + name.slice(1);

  /**
   * WHAT KIND OF PANE THIS IS, over the name of the one you are looking at.
   *
   * `Panel`'s rule, in its own words: *an eyebrow names the kind and a title names the instance*.
   * Every pane here was drawing the instance alone -- "Bob Smith", "Storage", and, for a boot, a
   * bare number plate, because `server.lua` sets `trunk.label` to the plate. A player reading
   * `GHST 001` at the top of a pane full of jerry cans has to work out from the contents which
   * car they are standing behind.
   *
   * The kind comes from `inventory.type`, which Lua already sends and nothing else on the screen
   * spends. An unmapped type draws NO eyebrow rather than its own slug: `policeevidence` over a
   * pane is worse than nothing, and a resource can register any type it likes.
   */
  const KINDS: Record<string, string> = {
    stash: 'Stash',
    shop: 'Shop',
    crafting: 'Crafting',
    container: 'Bag',
    trunk: 'Boot',
    glovebox: 'Glovebox',
    drop: 'Ground',
    newdrop: 'Ground',
    dumpster: 'Dumpster',
  };

  /**
   * `player` is two different panes. The left one is you; the right one is somebody whose pockets
   * you are looking through, and calling that "Yours" would be the single most misleading word on
   * the screen. Told apart by identity rather than by the `container` flag, which answers a
   * different question.
   */
  const kind = $derived.by(() => {
    if (inventory.type === InventoryType.PLAYER) {
      return inventory.id === inv.leftInventory.id
        ? locale.ui_kind_yours || 'Yours'
        : locale.ui_kind_player || 'Player';
    }

    return locale[`ui_kind_${inventory.type}`] || KINDS[inventory.type];
  });

  /**
   * A CATALOGUE PANE MAY HIDE; A PLACE MAY ONLY DIM.
   *
   * buildInventory expands Lua's sparse slot list into a dense array so that slot N sits
   * at index N-1 and every empty slot is still a drop target. Filtering that array in the
   * player's own inventory — or a stash, or a drop — deletes exactly the holes people drop
   * into. So those panes keep every slot rendered and grey the non-matches instead.
   *
   * A shop or a crafting bench is a list of things you can have, not a place you can put
   * things: nothing in it is a drop target, so removing rows is safe and is the only way a
   * long catalogue becomes navigable.
   */
  const catalogue = $derived(
    inventory.type === InventoryType.SHOP || inventory.type === InventoryType.CRAFTING,
  );

  /**
   * Tidying is only meaningful where slots are yours to rearrange. A shop's layout is the
   * shopkeeper's, and a crafting bench's is the recipe list.
   */
  const tidyable = $derived(!catalogue && inventory.slots > 0);

  let tidying = $state(false);

  async function runTidy() {
    if (tidying || inv.isBusy) return;

    tidying = true;

    try {
      await tidy(inventory.type);
    } finally {
      tidying = false;
    }
  }

  /** Label as the slot itself renders it, so searching matches what the player reads. */
  const slotText = (slot: Slot) =>
    `${slot.metadata?.label ?? ''} ${itemDefs[slot.name!]?.label ?? ''} ${slot.name ?? ''}`.toLowerCase();

  /**
   * Both filters at once, and both have to pass.
   *
   * Chips narrow to a kind of thing and the field narrows to a name, so the useful
   * combination is "the medical thing whose name has 'ban' in it" rather than either
   * replacing the other.
   */
  const matches = (slot: Slot) =>
    (!needle || (isSlotWithItem(slot) && slotText(slot).includes(needle))) &&
    (!chosen || categoryOf(slot) === chosen);

  const filtering = $derived(!!needle || !!chosen);
  const rows = $derived(catalogue && filtering ? inventory.items.filter(matches) : inventory.items);

  let visible = $derived(rows.slice(0, (page + 1) * PAGE_SIZE));
  const hasMore = $derived(visible.length < rows.length);

  // Wrapped rather than passed by reference: `some` supplies the index as the second
  // argument, which isSlotWithItem reads as its `strict` flag — so every slot after the
  // first would be tested strictly.
  const filled = $derived(inventory.items.some((slot) => isSlotWithItem(slot)));
  const hits = $derived(filtering ? inventory.items.filter(matches).length : -1);

  // Switching panes (opening a different stash) has to start from the top again, and the
  // previous pane's search must not silently narrow the new one.
  $effect(() => {
    inventory.id;
    inventory.type;
    page = 0;
    query = '';
    chosen = null;
  });

  /**
   * Drop a chosen chip once the pane no longer contains that category.
   *
   * Taking your last bandage out of a stash while 'Medical' is selected would otherwise
   * leave the pane filtered to nothing by a button that is no longer on screen.
   */
  $effect(() => {
    if (chosen && !present.some(([name]) => name === chosen)) chosen = null;
  });

  /**
   * The visible half of `isBusy`, on a delay.
   *
   * Almost every move answers in well under a frame or two, and flashing a working state
   * on each one is worse than showing nothing. This only appears once a round-trip is slow
   * enough that the player would otherwise think the UI had frozen — which, before this,
   * was indistinguishable from it having frozen, because isBusy's only effect was to
   * switch pointer-events off.
   */
  const BUSY_DELAY_MS = 180;
  let stalled = $state(false);

  $effect(() => {
    if (!inv.isBusy) {
      stalled = false;
      return;
    }

    const timer = setTimeout(() => (stalled = true), BUSY_DELAY_MS);
    return () => clearTimeout(timer);
  });

  const weight = $derived(
    inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0,
  );

  const load = $derived(inventory.maxWeight ? (weight / inventory.maxWeight) * 100 : 0);

  /**
   * How full, in words.
   *
   * The bar has changed tone past 90% since it was written, but nothing outside the bar
   * reacted — so the only warning a player got was six pixels of colour they were not
   * looking at, and the first they knew of being full was a pickup that quietly failed.
   *
   * Thresholds match WeightBar's so the readout and the bar never disagree.
   */
  const strain = $derived(load > 90 ? 'over' : load > 75 ? 'heavy' : null);

  const strainLabel = $derived(
    strain === 'over'
      ? locale.ui_overloaded || 'Overloaded'
      : strain === 'heavy'
        ? locale.ui_heavy || 'Heavy'
        : '',
  );

  /** What an empty pane should say, which is not the same sentence in every pane. */
  const emptyLabel = $derived.by(() => {
    switch (inventory.type) {
      case InventoryType.SHOP:
        return locale.ui_empty_shop || 'Nothing for sale here';
      case InventoryType.CRAFTING:
        return locale.ui_empty_crafting || 'Nothing can be made here';
      case InventoryType.PLAYER:
        return locale.ui_empty_player || 'You are carrying nothing';
      default:
        return locale.ui_empty || 'Empty';
    }
  });

  /** Load the next page when the sentinel below the grid scrolls into view. */
  function sentinel(node: HTMLElement) {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && hasMore) page += 1;
      },
      { threshold: 0.5 },
    );

    observer.observe(node);
    return { destroy: () => observer.disconnect() };
  }

  const format = (grams: number) => (grams / 1000).toLocaleString('en-us', { maximumFractionDigits: 2 });
</script>

{#if ownPane}
  <UsefulControls bind:open={helpOpen} />
  <SettingsPanel bind:open={settingsOpen} />
{/if}

<div class="w-bag">
<Panel eyebrow={kind} title={inventory.label ?? ''} scroll={false}>
  {#snippet actions()}
    <!-- One row of icon-only ghost buttons, pinned right by Panel's own header layout —
         no more hand-rolled auto-margin box for them to share. -->
    {#if bagSlot}
      <Button
        variant="ghost"
        selected={bagOpen}
        onclick={toggleBag}
        label={bagLabel || locale.ui_backpack || 'Backpack'}
      >
        <Icon node={Backpack} size="14px" />
      </Button>
    {/if}

    {#if container}
      <Button variant="ghost" onclick={() => fetchNui('closeContainer')} label={locale.ui_close || 'Close'}>
        <Icon node={X} size="14px" />
      </Button>
    {/if}

    {#if tidyable}
      <Button
        variant="ghost"
        onclick={runTidy}
        disabled={tidying || inv.isBusy}
        label={locale.ui_tidy || 'Tidy'}
      >
        <Icon node={ArrowDownAZ} size="14px" />
      </Button>
    {/if}

    {#if searchable}
      <Button
        variant="ghost"
        selected={searching}
        onclick={toggleSearch}
        label={locale.ui_search || 'Search'}
      >
        <Icon node={Search} size="14px" />
      </Button>
    {/if}

    <!-- The controls sheet and the settings panel. They were bare glyphs under the verbs, over the
         moving world in `--color-dim` -- the one ink colour this tree's own rule says never
         survives it. Here they have the header's surface under them and the same material as
         every other button on it. -->
    {#if ownPane}
      <Button
        variant="ghost"
        onclick={() => (helpOpen = true)}
        label={locale.ui_usefulcontrols || 'Controls'}
      >
        <Icon node={Info} size="14px" />
      </Button>
      <Button
        variant="ghost"
        onclick={() => (settingsOpen = true)}
        label={locale.ui_settings || 'Settings'}
      >
        <Icon node={Settings} size="14px" />
      </Button>
    {/if}
  {/snippet}

  <div class="body-stack">
  {#if inventory.maxWeight}
    <!-- The carry figure lives IN THE BAG'S OWN HEAD now, as a kit `Bar` with its readout —
         not a corner plate hovering outside the panel. `strainLabel` folds into the same
         readout string rather than a second line, so a heavy or overloaded bag still says
         so in the one place a player is already looking. -->
    <Bar
      value={load / 100}
      tone={strain === 'over' ? 'danger' : strain === 'heavy' ? 'warn' : 'primary'}
      label={locale.ui_carrying || 'Carrying'}
      readout={`${strainLabel ? strainLabel + ' · ' : ''}${format(weight)} / ${format(inventory.maxWeight)} kg`}
    />
  {/if}

  {#if searchable && searching}
    <!--
      `Field`, and this file is one of three that wrote it. `ghst_emotes`' animation menu and
      `ghst_appearance`'s pack picker had the same box -- a glyph, a bare input, a 2px left border
      reserved as transparent at rest, and a focus state that is a `--primary-glow` wash plus a
      `--color-primary` rail down that reserved edge. Three authors reading ox_lib's `InputRow` and
      none of them able to import it.

      **The third state came from here and goes out to the other two.** A field holding a query
      while the caret is elsewhere kept the accent on the frame and the glyph and dropped the wash,
      so a player reading a filtered grid can see *why* it is short. It is derived from the value
      in the component rather than passed, which is what retires the `class:active` this had.
    -->
    <div bind:this={field}>
    <Field
      bind:value={query}
      label={locale.ui_search || 'Search'}
      placeholder={locale.ui_search || 'Search'}
    >
      {#snippet glyph()}<Icon node={Search} size="13px" />{/snippet}
      {#snippet clearGlyph()}<Icon node={X} size="11px" />{/snippet}
    </Field>
    </div>
  {/if}

  {#if chipped}
    <!--
      A RADIO GROUP, AND NOT `SegmentedNav` -- which was tried here and does not fit.
      Written down because the inconsistency is the sort somebody arrives to correct.

      `All` is the half worth keeping and is new: the row used to clear by pressing the active
      chip a second time, which is a way back that nothing on screen advertised. A chip that says
      so, carrying the pane's whole count, is what the mockup drew and what a player can see.

      What the kit strip cannot do is hold a row THIS one is the wrong shape for. `.seg` is a
      pill rail: `inline-flex`, no wrap, no scroll -- correct for a designed, fixed set of tabs
      whose widths an author sized the rail against. These options are not designed. They are
      built from the categories the player happens to be carrying, so both how many there are and
      how wide each one is are data. Five of them measured 485px inside a 464px pane on the first
      try, and a sixth is one looted medkit away. A row that wraps is the only shape that survives
      that, and the kit has no wrapping strip to reach for.

      `aria-pressed` is gone with the toggle, though: this is a radio group now -- exactly one
      chip is on, `All` included -- and it says so.
    -->
    <div class="chips" role="radiogroup" aria-label={locale.ui_category || 'Category'}>
      <button
        class="chip"
        class:on={chosen === null}
        role="radio"
        aria-checked={chosen === null}
        onclick={() => (chosen = null)}
      >
        {locale.ui_cat_all || 'All'}<span class="tally">{itemCount}</span>
      </button>
      {#each present as [name, count] (name)}
        <button
          class="chip"
          class:on={chosen === name}
          role="radio"
          aria-checked={chosen === name}
          onclick={() => (chosen = name)}
        >
          {chipLabel(name)}<span class="tally">{count}</span>
        </button>
      {/each}
    </div>
  {/if}

  <!-- isBusy blocks interaction while a move is in flight, so a second drag cannot race
       the first. The store also refuses concurrent operations outright; this is the
       visible half of that — `stalled` adds the part the player can actually see, but
       only once a round-trip is slow enough to be worth mentioning. -->
  <div
    class="slots slot-grid"
    class:stalled={stalled || tidying}
    style:--grid-rows={gridRows}
    style:pointer-events={inv.isBusy || tidying ? 'none' : 'auto'}
  >
    {#each visible as item (item.slot)}
      <InventorySlot
        {item}
        inventoryType={inventory.type}
        inventoryGroups={inventory.groups}
        dimmed={!catalogue && filtering && !matches(item)}
      />
    {/each}

    {#if hasMore}
      <div class="sentinel" use:sentinel></div>
    {/if}

    <!-- Three different nothings, and they are not interchangeable: a pane that holds
         nothing, a search that found nothing, and a pane that failed to load look
         identical without this. -->
    {#if !filled}
      <div class="nothing"><EmptyState message={emptyLabel} /></div>
    {:else if filtering && hits === 0}
      <div class="nothing">
        <EmptyState message={locale.ui_no_results || 'Nothing matches'} />
      </div>
    {/if}
  </div>
  </div>
</Panel>
</div>

<style>
  .w-bag {
    display: flex;
    min-height: 0;
    max-height: 100%;
    width: var(--pane-width);
  }

  /* Same padding as Panel's own head (--space-4), not the old bespoke --pane-pad -- so the
     body's left/right inset lines up with the title above it, and app.css's --slot-base
     divides the same constant back out of --pane-width. */
  .body-stack {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-height: 0;
    padding: var(--space-4);
  }

  /* Height comes from .slot-grid in app.css: a fixed five rows, so both panes match
     whatever they hold. grid-auto-rows keeps a partly-filled last row square. */
  .slots {
    display: grid;
    grid-template-columns: repeat(var(--grid-cols), var(--slot-size));
    grid-auto-rows: var(--slot-size);
    gap: var(--slot-gap);

    /*
     * Grow rightwards into the panel's right padding by exactly the scrollbar's width,
     * so the scrollbar is drawn *in* that padding rather than beside it.
     *
     * Without this the gap from the last column to the panel edge is the padding plus
     * the scrollbar, while the gap on the left is the padding alone — a visibly
     * lopsided panel, and worse the wider the client's scrollbar is. With it the
     * columns sit symmetrically, and --grid-scrollbar drops out of the pane's width sum
     * entirely, so an unexpected scrollbar width can no longer clip a column either.
     */
    margin-right: calc(-1 * var(--grid-scrollbar));

    /* The columns are a fixed width and there are always exactly --grid-cols of them,
       so there is no circumstance in which this should scroll sideways. Saying so
       outright is what actually guarantees no horizontal scrollbar. */
    overflow-x: hidden;

    /* Always `scroll`, never `auto`: a six-slot crafting bench and a forty-slot
       inventory then reserve the same gutter and their columns line up, instead of
       differing by the width of a scrollbar depending on how full they are. The track
       is transparent, so an unused one is invisible. */
    overflow-y: scroll;
  }

  .sentinel {
    grid-column: 1 / -1;
    height: 1px;
  }

  /* ---- Search ------------------------------------------------------------ */

  /*
   * `.search` and its five rules -- the frame, the reserved left rail, `:focus-within`, `.active`
   * and the clear button -- are `Field`. The third state this file invented went into the
   * component and out to the other two resources that draw a filter box.
   */

  /* ---- Category chips ---------------------------------------------------- */

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .chip {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-0-5) var(--space-2);
    background: var(--tint-sunken);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-full);
    color: var(--color-dim);
    font-size: var(--text-meta);
    letter-spacing: var(--tracking-label);
    font-family: var(--font-display);
    text-transform: uppercase;
    transition:
      background var(--dur-fast) var(--ease-out),
      border-color var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out);
  }

  .chip:hover {
    border-color: var(--primary-glow-border);
    color: var(--color-white);
  }

  /*
   * A CHIP KEEPS ITS FILL AND ITS FOUR-SIDED EDGE, and takes the tree's one selected wash.
   *
   * The rail rows and fields take is refused here for `ghst_chat`'s `Segmented.svelte` reason: a
   * rail needs an edge long enough to read, and a fully rounded chip two lines of small type tall
   * has none. What changes is the token -- `--layer-selected` is the accent at 14%, a second
   * answer to "this one is chosen" at a different alpha from the `--primary-glow` a menu row and
   * a focused field both take. The stacked-layer form goes with it: replacing the chip's own
   * `--tint-sunken` with the wash is what `InputRow`'s `.control:focus` does, and it needs no
   * gradient to composite two colours on one box.
   */
  .chip.on {
    background: var(--primary-glow);
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .tally {
    font-family: var(--font-mono);
    letter-spacing: 0;
    color: var(--color-dim);
  }

  .chip.on .tally {
    color: var(--color-primary);
  }

  /* ---- Empty and stalled ------------------------------------------------- */

  /* `.empty` is `EmptyState`, `text-wrap: balance` and all -- see that component, which is where
     the balance belongs: a centred sentence with one word on the second line is the failure it
     prevents, and a centred sentence is what it is. What is left here is the grid placement, which
     is this pane's business and not a component's. */
  .nothing {
    grid-column: 1 / -1;
    align-self: center;
  }

  /* Deliberately understated: a move that takes a moment is not an error, and the grid
     has to stay readable underneath. The cursor carries most of the message. */
  .stalled {
    cursor: progress;
    opacity: 0.55;
    transition: opacity var(--dur-base) var(--ease-out);
  }
</style>
