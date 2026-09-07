<script lang="ts">
  import { inv } from '../lib/inventory.svelte';
  import { fetchNui } from '../lib/nui';
  import { items as itemDefs, locale } from '../lib/state.svelte';
  import { closeGivePicker, givePicker } from '../lib/ui.svelte';
  import Icon from '../lib/Icon.svelte';
  import Row from '../lib/Row.svelte';
  import { User } from '../lib/icons';
  import CountDialog from './CountDialog.svelte';

  /**
   * Which of the people standing here gets it, and how many.
   *
   * The name picker was already here; the count was not — Give sent whatever sat in
   * InventoryControl's amount box before the drag started. The design walk then made the
   * three questions one shape, so the hand-rolled dialog is gone and this is `CountDialog`
   * with a list of people above the count.
   *
   * A ROW SELECTS; IT DOES NOT GIVE. Every row used to be a button that handed the item
   * over on click, which put the irreversible action on the same gesture as "let me see
   * who is here" and left the count above it as something you had to remember to set
   * *first*. Now the list is a choice, the commit is the one filled button, and it is
   * disabled until somebody is chosen — the walk's one-filled-button rule, and the reason
   * the button can carry the name.
   *
   * The picker is only shown when there are at least two candidates — one person needs no
   * question asked, and none is not a choice. See onGive for where that is decided.
   */

  const open = $derived(givePicker.open);

  /** Named at the top so it is obvious what is being handed over, not just to whom. */
  const item = $derived(inv.leftInventory.items[givePicker.slot - 1]);
  const label = $derived(
    item?.metadata?.label || itemDefs[item?.name ?? '']?.label || item?.name || '',
  );

  const max = $derived(item?.count ?? givePicker.count);

  let count = $state(1);
  let target = $state<number | null>(null);

  const chosen = $derived(givePicker.targets.find((t) => t.id === target));

  $effect(() => {
    if (!open) return;

    count = Math.max(1, Math.min(max, givePicker.count || 1));
    target = null;
  });

  function give() {
    const { slot } = givePicker;

    // Read before the store is cleared: closeGivePicker empties the list this was chosen from.
    const to = target;

    closeGivePicker();

    // The payload is unchanged from the picker this replaces — client.lua's `giveItemTo`
    // takes the server id, the slot and the count, and nothing about the redraw touches it.
    if (to !== null) fetchNui('giveItemTo', { target: to, slot, count });
  }
</script>

{#if open}
  <CountDialog
    eyebrow={locale.ui_give || 'Give'}
    title={label}
    blurb={locale.ui_give_blurb || "Somebody within arm's reach."}
    {max}
    bind:count
    confirm={chosen
      ? `${locale.ui_give || 'Give'} ${count} ${locale.ui_to || 'to'} ${chosen.label}`
      : locale.ui_give_pick || 'Choose somebody'}
    disabled={!chosen}
    onconfirm={give}
    oncancel={closeGivePicker}
  >
    {#snippet before()}
      <!-- The well: rows clipped by the tint so the first and last take its corners, the
           shape every list in the pass sits in. Six people in reach is already unusual;
           past that the dialog's own body scrolls. -->
      <div class="well">
        {#each givePicker.targets as person (person.id)}
          <Row
            label={person.label}
            meta={`#${person.id}`}
            selected={person.id === target}
            onclick={() => (target = person.id)}
          >
            {#snippet glyph()}<Icon node={User} size="1.1em" />{/snippet}
          </Row>
        {/each}
      </div>
    {/snippet}
  </CountDialog>
{/if}

<style>
  .well {
    display: flex;
    flex: none;
    flex-direction: column;
    overflow: hidden;
    border-radius: var(--radius-md);
    background: var(--tint-sunken);
  }
</style>
