<script lang="ts">
  import { onDrop, onGive, onUse } from '../lib/actions';
  import { fetchNui } from '../lib/nui';
  import { anchored } from '../lib/position';
  import { isPinned, pinnable, togglePin } from '../lib/pins.svelte';
  import { items as itemDefs, locale } from '../lib/state.svelte';
  import { closeContextMenu, contextMenu, openCountPrompt, openWeaponPanel } from '../lib/ui.svelte';
  import { setClipboard } from '../utils/setClipboard';
  import { InventoryType } from '../typings';

  /**
   * Right-click menu for a player-inventory slot.
   *
   * Replaces the floating-ui Menu primitive, which brought focus management, typeahead,
   * list navigation and safe-polygon hover with it. None of that is reachable here: the
   * menu is opened by right-click, dismissed by clicking away, and has exactly one level
   * of nesting (attachments, and any grouped buttons an item declares).
   */

  interface Entry {
    label: string;
    run?: () => void;
    children?: Entry[];
    /** First of a group: draws the divider above itself. See `entries` below. */
    starts?: boolean;
  }

  const item = $derived(contextMenu.item);

  /**
   * Items can declare their own buttons in Lua, optionally tagged with a `group`. Runs of
   * buttons sharing a group collapse into one submenu; ungrouped ones stay inline. The
   * index is the button's position in the original array, which is what `useButton`
   * expects — so it has to be captured before any grouping rearranges them.
   */
  function itemButtons(): Entry[] {
    const buttons = (item?.name ? itemDefs[item.name]?.buttons : undefined) as
      | Array<{ label: string; group?: string }>
      | undefined;

    if (!buttons?.length) return [];

    const out: Entry[] = [];
    const groups = new Map<string, Entry>();

    buttons.forEach((button, index) => {
      const entry: Entry = {
        label: button.label,
        run: () => fetchNui('useButton', { id: index + 1, slot: item!.slot }),
      };

      if (!button.group) return void out.push(entry);

      let group = groups.get(button.group);

      if (!group) {
        group = { label: button.group, children: [] };
        groups.set(button.group, group);
        out.push(group);
      }

      group.children!.push(entry);
    });

    return out;
  }

  const entries = $derived.by<Entry[]>(() => {
    if (!item) return [];

    /**
     * Drop asks how many, through the same `CountControl` Split uses — but only when
     * there is a choice to make. A stack of one has nothing to ask about, and asking
     * anyway would be a dialog with one honest answer already selected.
     */
    const dropAll = () =>
      onDrop({ inventory: InventoryType.PLAYER, item: { name: item.name, slot: item.slot } });

    const runDrop = () => {
      if ((item.count ?? 0) <= 1) return dropAll();

      const label = item.metadata?.label || itemDefs[item.name!]?.label || item.name || '';

      openCountPrompt(
        label,
        locale.ui_drop || 'Drop',
        locale.ui_drop_blurb || 'On the ground, where you stand.',
        item.count!,
        (amount) => onDrop({ inventory: InventoryType.PLAYER, item: { name: item.name, slot: item.slot } }, undefined, amount),
      );
    };

    /*
     * THREE GROUPS, AND THE DIVIDERS ARE THE ONLY THING SAYING SO.
     *
     * A pistol lists ten entries, and every one of them carried an identical hairline -- which is
     * a table, not a menu. Uniform separation is the same as none: it tells you where a row ends
     * and nothing about what belongs with what. The rule is inverted below, so a hairline appears
     * only where a group changes.
     *
     * The groups answer three different questions, and the third is the one the code already
     * argued for -- see the pin comment further down, which says pinning is about the square and
     * not the thing in it:
     *
     *   1. What you do with the thing.        Use, Give, Drop
     *   2. What this particular thing offers. Remove ammo, the serial, attachments, item buttons
     *   3. What the square does.              Pin / Unpin slot
     *
     * NO COLOUR, and Drop does not get any. A red menu row would be a tier this tree does not
     * have -- `--color-danger` is spent on state here (a bar, a badge) and never on chrome, and
     * `Button` has no destructive variant to borrow. Use, Give and Drop are peers anyway: three
     * things you can do with an item, which is exactly why they are one group.
     *
     * The pin moved below attachments to sit in its own group. Nothing depended on its position.
     */
    const list: Entry[] = [
      { label: locale.ui_use || 'Use', run: () => onUse(item) },
      { label: locale.ui_give || 'Give', run: () => onGive(item) },
      { label: locale.ui_drop || 'Drop', run: runDrop },
    ];

    /** Group 2 opens at whichever of these the item happens to have. */
    const offers: Entry[] = [];

    if (item.metadata?.ammo > 0) {
      offers.push({
        label: locale.ui_remove_ammo,
        run: () => fetchNui('removeAmmo', item.slot),
      });
    }

    if (item.metadata?.serial) {
      offers.push({
        label: locale.ui_copy,
        run: () => setClipboard(item.metadata?.serial || ''),
      });
    }

    /**
     * A weapon gets a panel instead of a submenu.
     *
     * Recognised by any of the three things only weapons carry: a serial, a components
     * array, or an ammo type on the definition. `components` alone would miss a gun with
     * nothing bolted to it, which is exactly the one whose panel is worth opening to see
     * that it has empty hands.
     */
    const isWeapon =
      item.metadata?.serial !== undefined ||
      item.metadata?.components !== undefined ||
      itemDefs[item.name]?.ammoName !== undefined;

    /**
     * Pinning is about the square, not the thing in it, so the entry says "slot".
     *
     * It is only offered in the player's own inventory — the menu only opens there today
     * anyway, but the restriction is real: a stash id changes with every property, boot
     * and drop, so pins kept per stash would grow without bound.
     */
    const slotEntries: Entry[] = [];

    if (pinnable(InventoryType.PLAYER)) {
      const on = isPinned(InventoryType.PLAYER, item.slot);

      slotEntries.push({
        label: on ? locale.ui_unpin || 'Unpin slot' : locale.ui_pin || 'Pin slot',
        run: () => togglePin(InventoryType.PLAYER, item.slot),
      });
    }

    if (isWeapon) {
      offers.push({
        label: locale.ui_attachments || 'Attachments',
        run: () => openWeaponPanel(item.slot),
      });
    }

    /*
     * A group that came out empty opens nothing. An item with no ammo, no serial, no attachments
     * and no buttons of its own is three verbs and a pin, and drawing a divider before the pin is
     * the whole of what a two-group menu needs -- marking the first entry of a group that is not
     * there would put a line under the last row of the menu.
     */
    const groups = [list, [...offers, ...itemButtons()], slotEntries].filter((g) => g.length > 0);

    return groups.flatMap((group, i) =>
      group.map((entry, j) => (i > 0 && j === 0 ? { ...entry, starts: true } : entry)),
    );
  });

  let openSubmenu = $state<string | null>(null);
  let submenuAnchor = $state<DOMRect | null>(null);

  function activate(entry: Entry) {
    if (entry.children) return;

    entry.run?.();
    closeContextMenu();
  }

  function hover(entry: Entry, event: MouseEvent) {
    if (!entry.children) {
      openSubmenu = null;
      return;
    }

    openSubmenu = entry.label;
    submenuAnchor = (event.currentTarget as HTMLElement).getBoundingClientRect();
  }

  const submenu = $derived(entries.find((entry) => entry.label === openSubmenu));

  /**
   * Dismiss on any press outside the menu. Registered on pointerdown rather than click so
   * the menu is gone before a drag can start underneath it.
   */
  function onPointerDown(event: PointerEvent) {
    const target = event.target;

    // Not always an Element — a press that lands on the document itself has no closest().
    if (!(target instanceof Element) || !target.closest('.menu')) closeContextMenu();
  }

  function onKeyDown(event: KeyboardEvent) {
    if (event.key === 'Escape') closeContextMenu();
  }
</script>

<svelte:window onpointerdown={onPointerDown} onkeydown={onKeyDown} />

{#if item && contextMenu.anchor}
  <div class="menu" use:anchored={{ anchor: contextMenu.anchor, options: { side: 'point', gap: 0 } }}>
    {#each entries as entry (entry.label)}
      <button
        class="entry"
        class:starts={entry.starts}
        class:parent={!!entry.children}
        class:active={openSubmenu === entry.label}
        onmouseenter={(event) => hover(entry, event)}
        onclick={() => activate(entry)}
      >
        <span>{entry.label}</span>
        {#if entry.children}<span class="chevron">›</span>{/if}
      </button>
    {/each}
  </div>

  {#if submenu?.children && submenuAnchor}
    <div
      class="menu submenu"
      use:anchored={{ anchor: submenuAnchor, options: { side: 'right', gap: 2 } }}
      onmouseleave={() => (openSubmenu = null)}
      role="menu"
      tabindex="-1"
    >
      {#each submenu.children as child (child.label)}
        <button class="entry" onclick={() => activate(child)}>{child.label}</button>
      {/each}
    </div>
  {/if}
{/if}

<style>
  /*
   * ONE PANEL, NOT A STACK OF CARDS — `ox_lib`'s `ContextMenu.svelte` is the reference.
   *
   * The `--space-1` gutter is gone and `overflow: hidden` takes its place: the panel is the
   * surface, an entry is a region of it, and the first and last entries clip to the panel's own
   * corners. That is what lets a row be full-bleed rather than a rounded box inset from an edge
   * the panel had already drawn.
   */
  .menu {
    position: fixed;
    z-index: 80;
    display: flex;
    flex-direction: column;
    min-width: 160px;
    background: var(--surface-raised);
    text-shadow: none;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    box-shadow: inset 0 1px 0 var(--edge-highlight), var(--shadow-panel);
    overflow: hidden;
  }

  /*
   * A FULL-BLEED SLAB WITH A HAIRLINE ABOVE IT.
   *
   * It was a rounded card in a gutter, which is the shape `ox_lib`'s context and list menus have
   * both stopped drawing: the only thing that should separate two rows is a one-pixel rule.
   * `border-top` rather than `border-bottom`, so the rule falls between rows and never under the
   * last one, where it would read as a line the panel drew across itself.
   */
  .entry {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
    border: 0;
    /* Reserved at rest so a group boundary does not shift the rows below it. */
    border-top: 1px solid transparent;
    /* Reserved at rest so the row does not shift when it takes the rail. */
    border-left: 2px solid transparent;
    border-radius: 0;
    color: var(--color-gray);
    font-size: var(--text-sm);
    text-align: left;
    white-space: nowrap;
    transition:
      background-color var(--dur-fast) var(--ease-out),
      border-left-color var(--dur-fast) var(--ease-out),
      color var(--dur-fast) var(--ease-out);
  }

  /*
   * The only hairlines in the menu, and there are at most two of them.
   *
   * Every row used to carry one, with `:first-child` turning the top one off -- ten identical
   * lines, which separate rows from each other and say nothing about what belongs together. The
   * border is reserved on every row above and painted only here, so the panel is read as blocks
   * and the rows inside a block are read as a run.
   */
  .entry.starts {
    border-top-color: var(--color-border);
  }

  /*
   * HOVER IS A NEUTRAL WASH AND A RAIL; A HELD-OPEN PARENT IS THE ACCENT ONE.
   *
   * Both were one stacked-layer fill, which said the same thing twice and said neither of them
   * as an edge. The two are different statements and now read as such: the pointer is passing
   * over this (neutral, per `ContextButton`), versus this entry's submenu is open and the
   * pointer has moved off into it (accent, per the reference's selected row). Without the
   * second, walking into a submenu made the parent look abandoned.
   */
  .entry:hover {
    background-color: var(--tint-raised);
    border-left-color: var(--color-primary);
    color: var(--color-white);
  }

  .entry.active {
    background-color: var(--primary-glow);
    border-left-color: var(--color-primary);
    color: var(--color-white);
  }

  .chevron {
    color: var(--color-dim);
  }

  /* The gap between a parent entry and its submenu is only 2px, but the pointer still
     crosses it. Widening the submenu's hit area upward stops the menu closing when the
     cursor clips the corner — the cheap half of what floating-ui's safePolygon did. The
     padding survived the gutter's removal because it is a hit area rather than a gutter:
     it is on this one menu, on one side, and deleting it reintroduces the bug. */
  .submenu {
    padding-top: var(--space-1-5);
    margin-top: -4px;
  }
</style>
