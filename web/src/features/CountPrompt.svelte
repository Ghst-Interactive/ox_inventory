<script lang="ts">
  import { closeCountPrompt, countPrompt } from '../lib/ui.svelte';
  import CountDialog from './CountDialog.svelte';

  /**
   * How many to move — Split's own prompt, promoted to serve Drop as well. Both ask the
   * identical question; `countPrompt.verb` and its blurb are the only things that tell
   * them apart, on the eyebrow and the commit button.
   *
   * Opened by Alt-releasing a drag (Split) or choosing Drop on a stack of more than one
   * (Drop). Alt was the one free modifier: RMB is the context menu, Ctrl+LMB quick-moves,
   * Shift+drag halves, Ctrl+Shift+LMB moves half. Alt+LMB uses an item, but that is a
   * *click* — a press that never passes the drag threshold — so it and Alt+drag can
   * coexist without ambiguity.
   *
   * The frame, the count control, the keys and the hint plate are `CountDialog`'s, shared
   * with Give. What is left here is the store, the clamp and the commit.
   */

  const open = $derived(countPrompt.open);
  const max = $derived(countPrompt.max);

  let count = $state(1);

  /**
   * Reset each time the prompt opens.
   *
   * Half is the useful default: it is what shift-drag would have given, so the common
   * case stays one keypress (Enter) and the uncommon one is a drag of the slider or a
   * typed digit.
   */
  $effect(() => {
    if (!open) return;
    count = Math.max(1, Math.floor(max / 2));
  });

  function confirm() {
    const commit = countPrompt.commit;
    const amount = Math.max(1, Math.min(max, Math.round(count) || 1));

    closeCountPrompt();
    commit?.(amount);
  }
</script>

{#if open}
  <CountDialog
    eyebrow={countPrompt.verb}
    title={countPrompt.label}
    blurb={countPrompt.blurb}
    {max}
    bind:count
    confirm={`${countPrompt.verb} ${count}`}
    onconfirm={confirm}
    oncancel={closeCountPrompt}
  />
{/if}
