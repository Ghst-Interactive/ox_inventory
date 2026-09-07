<script lang="ts">
  /**
   * What a list says when it has nothing in it.
   *
   * ONE FILE WITH COPIES, **authored in `ox_lib`** — see `Row.svelte` for the licence routing.
   *
   * ## Why this is a component when most of its callers are one `<p>`
   *
   * 38 sites draw `<p class="empty">…</p>` and, taken alone, wrapping that in a component buys an
   * import and nothing else. What makes it worth having is the two things some of them already do
   * and the rest do not: a glyph, and a way out.
   *
   * The wording is not this file's business and should not become uniform. The tree's existing
   * empties are good precisely because they are specific — *"Nobody is asking you for anything,
   * and you have asked nobody"*, *"Clear this before borrowing again"* — and a component that
   * offered a default message would have every list saying "No items".
   *
   * ## Two emptinesses, and telling them apart is the point
   *
   * A list that is empty because nothing exists yet is a different fact from one emptied by a
   * filter, and only the second is the player's to undo. `ghst_appearance`'s wardrobe distinguishes
   * *"Nothing in this collection for this slot"* from *"Nothing here matches 'zzzz'"*, and the
   * second is where `action` earns its place — a way to clear the thing that emptied the list,
   * right where the player is looking for it.
   */
  import type { Snippet } from 'svelte';

  interface Props {
    /**
     * One sentence, written for this list.
     *
     * There is no default, on purpose. A component that supplied one would be adopted by supplying
     * nothing, and thirty-eight specific sentences would become thirty-eight identical ones.
     *
     * **A snippet is allowed, because two of these sentences name a thing.** Measured 2026-09-04:
     * 42 empty blocks in the tree, 6 carrying inline markup, and four of those six are `{#if}`
     * branches picking between plain strings — which a caller can compute. The two that are not
     * both want the same thing, a code identifier set in mono inside a sentence:
     * `ghst_admin`'s *"you need `ghst.log`"* and `ghst_music`'s *"add them to `Config.library` in
     * `shared/config.lua`"*.
     *
     * One prop rather than a second, so there is still exactly one way to say what a list says
     * when it is empty. The union widens the *form* of a message and changes nothing about the
     * argument above: the caller still has to write one.
     */
    message: string | Snippet;
    /**
     * A second line, under the message: what to do about it, or where the things went.
     *
     * Measured 2026-09-04, not assumed. 52 empty blocks in the tree; **five** already draw two
     * paragraphs, across four resources — `ghst_garages`' fleet app and its two world boards,
     * `ghst_phone`'s gallery, `ghst_multichar`'s empty slot. The pattern under all five is the
     * same and it is not decoration: the first line says *what is true*, the second says *what
     * follows from it*. `ghst_garages` puts it best by doing it — "Nothing is stored here" over
     * "N vehicles of yours are out in the world. Drive one back, or leave it where it is."
     *
     * Two lines rather than one longer sentence, because they are read at different moments: the
     * first answers the glance, the second is there when the glance was not enough.
     *
     * A snippet is allowed for the same reason `message` allows one.
     */
    detail?: string | Snippet;
    /** A glyph above the message. A ban, a magnifier — whatever the emptiness is about. */
    glyph?: Snippet;
    /** A way out: clear the filter, add the first one. Only for an emptiness the player made. */
    action?: Snippet;
  }

  let { message, detail, glyph, action }: Props = $props();
</script>

<div class="empty">
  {#if glyph}<span class="glyph">{@render glyph()}</span>{/if}

  <p class="message">
    {#if typeof message === 'string'}{message}{:else}{@render message()}{/if}
  </p>

  {#if detail}
    <p class="detail">
      {#if typeof detail === 'string'}{detail}{:else}{@render detail()}{/if}
    </p>
  {/if}

  {#if action}<div class="action">{@render action()}</div>{/if}
</div>

<style>
  /*
   * Centred and generously padded, because an empty state is the only content on its surface and
   * a sentence pinned to the top-left of a tall panel reads as a loading failure.
   */
  .empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-6) var(--space-4);
    text-align: center;
  }

  .glyph {
    display: grid;
    place-items: center;
    color: var(--color-dim);
    opacity: 0.7;
  }

  /* Dim, and body text rather than the display face. This is prose — the one place on a panel
     that is a sentence rather than a label, and setting it in the technical face would make an
     explanation look like a heading. */
  .message {
    max-width: 42ch;
    color: var(--color-dim);
    font-size: var(--text-sm);
    line-height: var(--leading-body);

    /*
     * Chromium 114, above the NUI ceiling of ~108, and left in deliberately with no fallback --
     * unread, the line wraps the ordinary way. `ox_inventory`'s grid had it and its note is the
     * argument: it is *"the only above-ceiling declaration in any of these bundles that is not
     * paired with a fallback, because it is the only one whose absence costs nothing."*
     *
     * It belongs here rather than there. A centred sentence with one word on the second line is
     * the failure this prevents, and a centred sentence is what this component *is*.
     */
    text-wrap: balance;
  }

  /*
   * A step down and no further dimming — `--color-dim` is already the quietest ink that meets the
   * contrast gate, and a second step would be a line the player cannot read explaining a line
   * they can. What separates the two is size and the gap, not brightness.
   *
   * With a detail present the message becomes the louder half of a pair, so it takes white. A
   * lone message stays dim: on its own it is the whole statement rather than a heading over one.
   */
  .message:not(:last-of-type) {
    color: var(--color-white);
  }

  .detail {
    max-width: 42ch;
    color: var(--color-dim);
    font-size: var(--text-meta);
    line-height: var(--leading-body);
  }

  .action {
    display: flex;
    gap: var(--space-2);
    padding-top: var(--space-1);
  }
</style>
