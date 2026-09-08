# What this fork changes

Forked from [overextended/ox_inventory](https://github.com/overextended/ox_inventory) for the
Ghst-dev server. The inventory *model* is upstream's — slots, weight, metadata, stashes,
shops, crafting, the whole server side — so upstream's documentation at
[overextended.dev/ox_inventory](https://overextended.dev/ox_inventory) still applies.

What differs is the interface, and a handful of seams cut for it.

Fork work lives on the **`ghst_ui`** branch, not `main`. `main` tracks upstream.

## Licence

**GPL-3.0**, as upstream. See [LICENSE](../LICENSE) and [NOTICE.md](../NOTICE.md), both
unmodified — the NOTICE file is Linden, Luke and Dunak's and states the terms this fork is
redistributed under.

Two of those terms matter here and are met by this document: *document any modifications made
to the original work*, and *preserve all copyright, license, and attribution notices*.

## The shape of it

| | |
|---|---|
| **52 files** under `web/src` | The NUI, rebuilt |
| **9 files** outside it | Seams the UI needed, plus the framework-strip patches |

Against `main` that is 126 paths changed, because 55 of them are the React tree being deleted.

## The UI is Svelte, not React

Upstream's NUI is React with `react-dnd`. This one is **Svelte 5 + Vite + Tailwind 4** on the
shared Ghst tokens, with a **pointer-event drag layer** in place of react-dnd — one dependency
instead of three, and a drag that works the same for mouse and touch.

The grid, the state, the tooltip, the context menu, the controls dialog, the hotbar and the
item notifications were all rebuilt rather than restyled.

## What the interface gained

None of this is upstream behaviour. It is the list worth reading if you are wondering why the
inventory looks unfamiliar.

| | |
|---|---|
| **Search, empty and busy states** | A pane says what it is doing rather than looking broken while it waits |
| **Refusals are spoken** | A drop that will be refused says so before you let go, and leaves a hole where the item was rather than snapping it back |
| **Hot slots without opening** | `1`–`5` use a slot without opening the inventory first |
| **Merged notifications** | Repeated ones collapse and carry colour; being overloaded says so |
| **Player settings** | Accent, slot size, tooltip delay and reduced motion, remembered per client |
| **A hotbar worth looking at** | It can stay up, and shows enough to be used |
| **Split at the drop** | Asked how many at the moment you drop, not through a separate dialog |
| **A weapon panel** | Instead of a submenu, with what is in your hands and how another compares |
| **Categories and filter chips** | Items carry a category; panes get a row of chips |
| **Tidy** | Merge what stacks, then order it — with pinned slots left alone |
| **Give, in place** | Pick who gets the item inside the inventory |
| **A ped preview** | A copy of the player beside the inventory. Off by default |
| **Bags open under your own pane** | On a button in its header, rather than replacing whatever you were looking at — [see below](#a-bag-opens-beside-the-inventory-not-instead-of-it) |
| **A voice** | Sound, without shipping a single audio file — see below |

## Sound without audio files

The inventory has audio and the repository has no `.ogg` in it. The five sounds are built in the
browser out of oscillators and filtered noise -- `web/src/lib/audio.ts`, a few numbers each -- so
nothing is streamed, nothing is decoded, and the only thing added to the bundle is that file.

The reason is `fxmanifest.lua`. Its `files` block globs exactly two things out of the built
bundle, `web/build/assets/*.js` and `*.css`; a loose `.ogg` beside them is not published by the
resource and 404s in game. Shipping a recorded clip would mean base64ing it into the JS chunk --
tens of kilobytes of string constant nobody can adjust without an audio editor. Changing one of
these is editing a frequency.

Volume is the shared `uiVolume` preference, so the inventory is as loud as everything else on the
server. See [ghst_prefs](#shared-preferences) below.

## A bag opens beside the inventory, not instead of it

The largest behaviour change here, and the one with the most rules behind it.

Upstream shows a container the same way it shows a stash: as the right-hand pane, replacing
whatever was there. Walking up to a stash wearing a backpack therefore meant choosing which of
the two you could see. A bag is now always a **third pane**, under your own inventory, on your
side of the control column — it is part of you, so it stays on your side.

**However it was opened.** Using a bag with the window shut used to take the other path and land
in the right-hand pane, so the same backpack had two presentations and one of them blocked the
stash. Worse, the header's bag button was hidden in exactly that state, so the control that
would have moved it was gone until the window was closed and reopened. `client.openContainer`
opens the window first when it has to, and `openInventory('container', slot)` — the export, the
only caller left — is routed to it, so the page can resolve a `container` on the wire to exactly
one pane.

**How the security survives it.** All of ox_inventory's transfer security rests on
`playerInventory.open` being a single id the *server* chose — `swapItems` resolves the non-player
side from it, which is why a client can never name an inventory. Widening `open` into a set would
hand that decision to the client for every inventory type at once. A container is the one
exception that costs nothing, because it is addressed by a **slot in the player's own inventory**
rather than by an id: the worst a forged `fromType = 'container'` can reach is a bag the player is
already carrying. So `open` is left alone and the bag is recorded in `containerSlot`, which the
server already maintained.

**One bag at a time.** `container` is a *type* on the wire, and the page resolves a type to a
pane — so two panes wearing it are two panes it cannot tell apart. With one place a bag can be,
using a second one replaces the first in that place. The server is single-minded for its own
reason: `containerSlot` is one field.

**Quick transfer follows the bag.** Ctrl+click moves an item to "the other pane", which for an
item in your pockets is the right-hand one — and that is now empty whenever only a bag is open.
So the player side falls back to the bag when no foreign inventory is open, which makes the
gesture do what it did before in both real cases: bag only, it goes to the bag; stash open, it
goes to the stash (`helpers.getTargetInventory`).

**The open bag does not move.** Every `container` move resolves through `containerSlot`, so a
move that empties or overwrites that slot leaves the field naming something else. The drag is
refused in the UI (`onDrop`) and again on the server (`swapItems`), rather than the field being
repointed — repointing means guessing where the bag landed, and closing the bag first is one
click.

**What stays impossible.** A bag cannot trade directly with a stash: the exploit guard at the top
of `swapItems` requires one side of any move to be the player, and that guard is worth more than
the convenience. The UI refuses that drag visibly rather than letting the server reject it. A
container cannot go inside a container either, which would nest weight calculations indefinitely.

## Shared preferences

Reduce motion, interface size and interface volume are not this inventory's settings. They belong
to the player, and `ghst_prefs` owns them for every interface on the server — so the switch here
and the one on the character screen are the same switch.

`modules/prefs/client.lua` is six lines carrying that transport the last step into the page, and
`web/src/lib/prefs.svelte.ts` is the copy of the shared client file every ghst UI has. A **soft
dependency**, deliberately: `ghst_prefs` is not in `fxmanifest`'s `dependencies{}`, because a
missing preferences resource should cost a player their preferences and not their inventory.

Nothing is applied optimistically. A control writes to Lua, Lua writes the KVP and broadcasts,
and the value arrives back through the listener — which is what stops two interfaces disagreeing
about the answer.

What stayed local is in `web/src/lib/settings.svelte.ts` and lives in `localStorage`: accent, slot
size, tooltip delay, hotbar mode and the pinned slots. Those describe this inventory and nothing
else.

## Icons: Lucide, not FontAwesome

Upstream inlines FontAwesome path data. This uses `web/src/lib/icons.ts`, the same explicit
Lucide allowlist every other UI on this server uses — static imports, unused icons dropped by
the bundler.

The trade is the same one: **a name that is not registered renders nothing**, silently, in a
production build. Check the name is on the list when adding a caller.

## Containers come from `data/`

Upstream hard-codes two demo containers at the bottom of `modules/items/containers.lua` — a
paperbag, and a pizzabox whose item does not exist. That file is fork code, so every server
that ever added a backpack edited it, and an upstream bump reverted the edit.

It loads `data/containers.lua` now, beside the item list whose names it has to match. `.sync`
excludes `data/`, so the deployed list survives a deploy exactly the way `items.lua` does, and
this repository's copy is a placeholder that never ships. A missing file is not an error:
`lib.load` returns nil, nothing is registered, and the container paths never fire.

## Ambient surfaces

The inventory takes NUI focus with the game held still behind it, so it keeps the **focused**
panel material throughout. It is listed here only because the shared ambient tier was added to
its `tokens.css` at the same time as everywhere else — nothing in this resource uses it, and
nothing should.

`web/tools/check-tokens.mjs` runs after every build and fails on a `var(--x)` with no fallback
that nothing declares.

## A locked car has a locked boot

One condition in `Inventory.CanAccessTrunk` (`modules/inventory/client.lua`), and the only
behaviour change outside the interface.

Upstream checks the vehicle class, the storage data, that a boot door exists and that you are
within a metre and a half of it — and never asks whether the vehicle is **locked**, so the boot
prompt appeared on every car within reach.

**This is the prompt, not the gate.** `openInventory`'s trunk branch on the server has always
tested `GetVehicleDoorLockStatus` and answered `vehicle_locked`, so a locked boot was never
actually lootable. What this line decides is whether the player is offered something that will
work — which is why it has to reach the *same* answer the server will.

It reads `Entity(entity).state.doorslockstate` and falls back to the native, rather than calling
`exports.ghst_vehiclekeys:IsAccessible`. The lock state is already replicated to every client, so
there is no round trip, no export call per frame, and no dependency on that resource being
started. The fallback is the part that matters: a world vehicle has no lock state until somebody
tries a door, and testing the statebag alone read every untouched car as unlocked — a prompt that
lies. `ghst_vehiclekeys` documents the same trap in `GhstKeys.lockState`, where reading "not 2"
as unlocked made a lockpick report a car it had never rolled for.

The values are the server's, verbatim: 0 no lock, 1 unlocked, 8 boot unlocked, everything else
locked. Testing `== 2` alone was safe only because `ghst_vehiclekeys` writes nothing but 1 and 2,
which stops being true the moment the native answers instead.

Keys are deliberately *not* consulted. Locked means locked, including for the owner, who
unlocks the car and then opens the boot. That is one extra press, and it is the same press a
thief has to earn.

## Cash has weight

`data/items.lua`, one field on two items, 2026-08-31:

```lua
['money']       = { label = 'Money',       weight = 0.1 },
['black_money'] = { label = 'Dirty Money', weight = 0.1 },
```

Upstream ships both weightless, and the consequence is bigger than the diff. A weightless note
means a player carries ten million dollars at no cost — and every decision this server had made
about money was arguing with that one missing field. `ghst_banking`'s withdrawal ceiling exists to
cap what a robbery is worth; its Fleeca card gates a machine; the bank account holds a balance. None
of them meant anything while the pocket was free.

**0.1g per dollar is friction, not realism.** A real $100 bill is about a gram, which would be 0.01
— and against this server's 85kg limit (`ox.cfg`, `inventory:weight`) that is $8.5 million in a
pocket. At 0.1, $5,000 is half a kilo and $500,000 is most of what a person can carry.

Two things a reader should know before changing it:

- **Fractional weights are safe.** `modules/items/shared.lua` defaults a missing weight to zero and
  never rounds; a slot's weight is `item.weight * count`.
- **It is retroactive and there is no migration.** A character already holding $2M is 200kg over
  and cannot pick anything up until they bank some of it. That is the pressure working as intended
  rather than a bug, but it happens the moment this deploys, to everyone at once.

The reasoning lives in `txData/ghst_sv/docs/economy.md` §3.1.

## Strength buys carry capacity

`modules/skills/server.lua` (new) and one call in `server.lua`, 2026-08-31:

```lua
maxWeight = inventory:weight + inventory:strengthweight * (strength rank / max rank)
```

`ghst_skills` carries a `strength` rank per character. This turns it into grams: rank 0 is
`inventory:weight` exactly — 85kg, what every character carries today and what the server did
before this file — and rank 100 adds `inventory:strengthweight`, 25kg by default. Set that convar
to `0` to switch the whole thing off without editing anything.

Capacity is applied twice: once at the end of `setPlayerInventory`, after the client has been sent
the inventory it is about to be told the new limit for, and again on `ghst_skills:rankChanged`
whenever a strength rank moves under a player who is already connected.

Three things worth knowing:

- **The direction is deliberate.** `maxWeight` is this resource's value and `Inventory.SetMaxWeight`
  is its only legitimate writer — it has a client event to fire afterwards. So the integration
  lives here and `ghst_skills` only answers what the rank is. Licensing permits this direction and
  not every direction: ox_inventory is GPL-3.0 like the `ghst_*` resources, where ox_lib (LGPL) and
  ox_target (MIT) are not. See `Tools/README.md`.
- **Start order does not matter.** `ghst_skills`' `GetRank` takes a source *or* a citizenid and
  falls back to reading qbx_core player metadata, so it answers correctly even when asked before
  that resource has loaded the character.
- **It only ever adds.** Nothing here can leave a player over a limit that just shrank. That stops
  being true if `inventory:strengthweight` is ever made negative — `SetMaxWeight` does not shed
  items, it only refuses more.

With `ghst_skills` stopped, `GetResourceState` sends every player back to the flat convar.

## Framework-strip patches

Two changes carried from the server's framework strip rather than invented here: the
`Item('phone')` handler in `modules/items/client.lua` and the npwd `setPhoneDisabled` block in
`client.lua`, both of which drove a resource that is not installed. `data/items.lua` also has
no `phone`, `radio`, `jammer` or `radiocell` item. **Re-adding npwd means undoing all four**,
and that is recorded in `txData/ghst_sv/README.md` as well as here.

**That fourth one is not in this repository.** `.sync` excludes `data`, so the item list that
ships is the deployed copy under `txData/ghst_sv/resources/[ox]/ox_inventory/data/`, and the
`data/items.lua` in *this* tree is still upstream's demo list — `phone` and `radio` are both in
it, with their original npwd calls, and neither is ever deployed. Reading this file and
concluding the strip missed something is a mistake that has been made; the deployed file's own
header lists all four as deliberately absent.

## Building

```bash
pnpm --dir Scripts/ox_inventory/web install
pnpm --dir Scripts/ox_inventory/web run dev
pnpm --dir Scripts/ox_inventory/web run build
```

The dev drawer is reached through a dynamic import behind `import.meta.env.DEV`, so it never
ships.

## Deployment

`.sync` marks this fork deployable into `[ox]`, replacing the upstream release copy that
`ghst_sv` used to track. `ghst_sv` gitignores that path now — the source of truth is this
repository. `data/` is excluded from the sync, because the item list, shops, stashes and the
container list are the *server's* content rather than the fork's.

## The design-walk pass, 2026-09-05

`txData/ghst_sv/docs/ui-tdu.md` §8's row for this resource: two bags at a fixed 500px, cash as a
slot, one count control shared by Give, Split and Drop, and weapon attachments as a live-model
camera screen. The first three landed on the day; the fourth followed it, and is the last section
below.

**Two bags at a fixed 500px.** `InventoryGrid.svelte` now wraps its slots in a kit `Panel`
instead of a hand-rolled `<section class="pane">`, and the carry figure moved from a header text
line plus a full-width `WeightBar` into a kit `Bar` with a `readout` string, drawn first in the
panel's body — the corner plate the walk rejected is gone. Sizing inverted: `app.css`'s
`--slot-base` used to be a viewport clamp (`clamp(68px, 9.5vh, 112px)`) that the walk found too
big; it is now derived *from* a fixed `--pane-width: calc(500 * var(--ui-px))`, five columns and
four gaps, so the bag is the fixed thing and the slot is whatever is left over. `--pane-pad` is
gone — the panel's own body padding is `--space-4`, the same constant the size formula divides
back out, so the header and the grid share one inset.

**Cash is a slot.** This one was already true and needed no code: `money`/`black_money` are
ordinary items (`fixtures.ts`'s `money` entry, `InventorySlot.svelte`'s rendering), drawn with the
same art-plus-count tile as everything else. There never was a cash corner plate to remove.

**One count control.** `features/CountControl.svelte` is new: a kit `Stepper` (exact typed digit,
arrows) plus a slider plus `SegmentedNav` quick chips (One / Half / All), reading and writing one
`value`. Three call sites now share it:

- **Split** — `SplitPrompt.svelte` is gone; `CountPrompt.svelte` replaces it and is deliberately
  generic (`countPrompt.verb` and its blurb are the only things that tell Split and Drop apart).
  Opened the same way (Alt-release), with the same `commit` closure contract.
- **Drop** — new. The context menu's Drop entry used to call `onDrop` directly with no amount,
  dropping the whole stack. It now opens the same `CountPrompt` when the stack is more than one
  and drops the chosen amount; a stack of one still drops instantly, matching Split's own
  precedent for not asking a question with one answer.
- **Give** — `GivePicker.svelte` is the same dialog with a list of people above the count.

**The three are one dialog now** (2026-09-05), which is the rest of the walk's row. `CountPrompt`
and `GivePicker` were a pointer-anchored popover and a hand-rolled window respectively — two
shapes for one question, and neither the centred kit `Panel` the gallery draws. Both now render
`features/CountDialog.svelte`: `Shell` + `Panel` with the verb as the eyebrow, the item as the
title, a blurb saying where the items go, the count control in the body and `Cancel` plus one
filled commit in the foot.

- **The anchor is gone rather than ignored.** `openCountPrompt` lost its `x, y` and gained the
  blurb: `(label, verb, blurb, max, commit)`. An argument nothing reads is one the next caller
  fills in carefully and wrongly. `contextMenu.anchor` is no longer consulted to decide whether
  Drop may ask.
- **A give row selects; it does not give.** Every row used to hand the item over on click, which
  put the irreversible action on the same gesture as looking at who is here. The filled button is
  disabled until somebody is chosen and then carries the name — "Give 2 to Sofia" — which is the
  walk's fold-in rule and the one filled button the screen gets.
- **`scrim="clear"`, not `scrim={false}`.** The mockup has no live grid behind it; this does, and
  the veil is what stops the dismissing click landing on a slot and starting another drag. It
  paints nothing, so the no-veil rule is kept.
- **Rows carry `#id` and no job or distance.** The mockup's people have a rank and a range;
  `getGiveTargets` answers with a server id and a name, and inventing the other two would be
  drawing data the client does not have.

**Every server message shape is unchanged.** `giveItemTo` still sends `{ target, slot, count }`,
`giveItem` still sends `{ slot, count }`, and Split/Drop still resolve through `onDrop`'s existing
`amount` parameter. No Lua touched, no NUI callback renamed.

**Hints.** A bottom-left `KeyHints tone="ambient"` plate was added to the main inventory screen
(Escape only — nothing else here has no other affordance). A dialog puts its own plate in that
same corner through `Shell`'s hint slot — `enter Confirm · esc Cancel` — and the inventory's
stands down while one is up, because two plates in one corner is two answers about one key.
Neither plate paints a ground: `KeyHints`' own rule is that a hint cluster is never a panel, and
this resource had already settled that for the plate in that corner before the mockup drew a
filled one.

### Weapon attachments, as a screen with the live model on it

The row's fourth item shipped on 2026-09-05, and the plan that used to sit here is what it was
built from. `AttachmentPanel.svelte` is no longer a 340px card listing what happens to be fitted
with an x beside each: it is the gallery's wide `Panel` -- the weapon as the head, a transparent
stage on the left with the model in it, the point's candidates and all the points as `Row`s on the
right, `Strip all` and one filled `Fit` in the foot. (The wide panel lasted three days -- see
*What the live session answered* below, where it becomes a full-screen `Shell` with the bags
hidden behind it.)

**The stage is a hole and Lua fills it.** `modules/weaponstage/client.lua` is new and is the whole
of the other half: on open it spawns a `CreateWeaponObject` above the player (twelve metres then,
three now -- see below), gives
it the components the slot's metadata says are fitted, and frames it with a scripted camera into
the rectangle the page reports. The framing arithmetic -- distance and two shifts solved from a
screen rect, a fill and a field of view -- is `ghst_customs/client/camera.lua`'s, GPL to GPL; the
orbit-and-zoom lifecycle is `ghst_appearance/client/camera.lua`'s. What is new is that the rect is
*given* rather than read out of a config: the page owns its layout and is the only thing that knows
where the hole ended up, so it measures its own element with a `ResizeObserver` and posts viewport
fractions.

**The dots are the page's; the projection is Lua's.** Each frame the module resolves every point to
a world position -- a weapon-model bone (`WAPScop`, `WAPSupp`, `WAPClip`, `WAPFlsh`, `WAPGrip`)
where one resolves, a fraction of the model's own bounding box where none does -- projects it with
`GetScreenCoordFromWorldCoord`, divides by the rect it already holds, and pushes
`{ id, x, y, visible }` per point. Fractions of the *stage*, not of the screen, so the page places a
dot at `left: x%` with no arithmetic and no second copy of the rect, and a fake point in the harness
is a pair of numbers a human can read off the mockup. An unchanged frame sends nothing.

**A point is a component `type`.** The seven ids -- sight, muzzle, barrel, flashlight, grip,
magazine, skin -- are exactly the seven distinct `type` values in `data/weapons.lua`'s `Components`,
so there is no second vocabulary to maintain and a component added later lands on a point that
already exists. A point the weapon takes nothing for is not drawn at all: `DoesWeaponTakeWeaponComponent`
answers which candidates are real for this weapon, which is why the catalogue is built client-side
rather than in the page.

**No second way to attach anything.** Fitting is `useItem` on the inventory slot holding the part --
the same call right-clicking it in the grid makes, reaching `client.lua`'s `useSlot` and its
`data.component` branch -- and Lua sends that slot with each candidate so the page never has to
find it. Removing is `removeComponent`, which this panel already used; `Strip all` is that call once
per fitted part, because it always was per part. "None" is a candidate in the same list rather than
an x on a row: one list, one commit button.

**The refusals are rows, not absences.** The existing rule -- Lua refuses on a weapon that is not
the one in hand and notifies separately -- is kept as the reason under the row and as a disabled
`Fit`. A part the player does not carry says "Not in your bag" rather than vanishing.

**Neither side is optimistic.** Both calls answer with a bare acknowledgement and the real change
arrives as `refreshSlots`, so the screen watches the slot's `metadata.components` in the store and
posts `refreshWeaponStage` when it moves. That is also why the effect reads nothing else: the
refresh answers with a `weaponStage` message, and an effect that read `stage` would wake itself.

**Five new NUI callbacks and two new messages**, all client-side, none of them a rename:
`openWeaponStage { slot, rect }`, `weaponStageRect { x, y, w, h }`, `weaponStageOrbit { dx, dy }`,
`weaponStageZoom { delta }`, `refreshWeaponStage`, `closeWeaponStage`; and back the other way
`weaponStage { slot, live, inHand, points[] }` and `weaponPoints { points[] }`. All six callbacks
and both messages are mirrored in the dev drawer -- `openWeaponStage` and `refreshWeaponStage` push
the fixture catalogue, and orbit and zoom move the fake dots, because a drag that visibly does
nothing is indistinguishable from a drag that is not wired up.

**What the live session answered, 2026-09-08.** The three things the section above said could not
be checked from here were checked, and two of them were wrong in the same direction: the screen was
too small for the thing it was showing.

1. **A weapon in the bag never had a model.** `CreateWeaponObject` returns 0 for a weapon whose
   asset is not streamed in, and nothing in the resource was streaming one — so the only weapon the
   screen could draw was the one in the player's hands, whose model is loaded by definition.
   Everything else fell straight through to "The weapon cannot be shown here", with no error,
   because a 0 from that native is a return value. `modules/weaponstage`'s `stream()` now takes the
   asset through `lib.requestWeaponAsset` first, which is why `Stage.start` yields and why both of
   its callers hand it a thread.
2. **The shot was mirrored.** The camera's right-hand vector was `(cos yaw, sin yaw)`; a camera
   standing at heading `yaw` *from* the model looks back along `(sin yaw, -cos yaw)`, whose right
   hand is the negative of that. The aim shifted the wrong way and the model landed reflected about
   the centre of the screen — outside its own stage, with the dots drawn past 100% of the element
   they are positioned inside. What a player saw was an empty rectangle over a distant camera
   angle, which reads as the camera being in the wrong place rather than the aim, and that is how
   it was reported.
3. **The lift was twelve metres and is now three.** Twelve only reads as sky *outdoors*; indoors it
   is inside the ceiling slab or above it and outside the interior's rooms, where the game culls
   what it draws. It is also not what keeps the backdrop out of shot — the framing is, and on a
   full-screen stage the solved camera distance is about two metres. Just clear of the ped is the
   only value that behaves the same in a garage as it does on a street.
4. **Everything past the player's first empty slot read "Not in your bag".** `carried()` walked
   `PlayerData.inventory` with `#` and a numeric loop, and that table is keyed by slot with a nil
   for an empty one — `#` on a sparse table is any border the implementation likes, so a gap at
   slot 4 ended the walk at 3. `pairs` now.

**And the panel became a screen.** Point 3 of the old list — legibility through the panel's own
plane — was real, and the answer was not a lighter surface. Three things followed from being a
`wide` panel centred over the two bags:

- The hole was a quarter of the screen wide, and Lua solves the camera distance *from* that
  rectangle, so the shot was eleven metres off a rifle: distant, high and wide-angle with the model
  a thumbnail in the middle of it.
- The one thing on the screen that is genuinely behind the page was being read through two
  translucent layers and the inventory underneath.
- Seven dot labels over a 440px rectangle is a pile.

So `Inventory.svelte` hides `.wrapper` while the screen is up — `display: none`, not an `{#if}`, so
the grids keep their component state and a bag scrolled halfway down is still that way on the way
back — and `AttachmentPanel.svelte` is now a `Shell` at `place="fill"`: the stage is the viewport
less one 340px rail, the weapon is named on an ambient plate over it, and the rows and the two
verbs are in the rail's `Panel`. The scrim went with the outer panel, because a click on the empty
part of this screen is a *drag to orbit* and click-outside-to-close cannot share an element with
it; Escape is the way back and the hint plate says so.

**The blur is suspended, not dropped.** `TriggerScreenblurFadeIn` is the only thing that can blur
the game behind a translucent pane, and it blurs the weapon too. Every other surface in this
resource wants that — the panes are read against the world and the world is not the content — and
this one is the exception, so `Utils.blurSuspend`/`blurResume` lend the inventory's single
`lib.screenBlur` hold out for the duration rather than releasing it. Held as a lend because
`client.closeInventory` calls `blurOut` on a path the module cannot see the ordering of; the two
flags in `modules/utils` make either order come out the same. (The flags stayed; the ordering did
not have to — see the next section.)

**The second live session, same day.** With a model finally on the stage, five more things showed
up — and the two that mattered most were both the framing rather than the camera.

1. **The height term was solving for a rifle stood on end.** `distance` is the larger of what the
   width needs and what the height needs, and the height term was `max(size.z, size.x)` — the
   weapon's *length*, in the vertical, which is only true looking straight down. At the resting
   pitch of eight degrees it asked for a metre of headroom on a stage holding a gun 30cm tall, so
   the height term won every time and stood the camera about fifty per cent further back than the
   shot needed: `fill` said 60% of the stage and the weapon drew at about 35%, in the middle of a
   lot of scenery. It is now `size.z * cos(pitch) + reach * sin(pitch)` — what the model actually
   spans vertically at the angle it is being looked at, which is the length only when the shot is
   top-down. `ghst_customs` avoids the whole question by solving from the free band's width alone;
   the term stays here because this stage can be short and wide, but it now measures something.
2. **`offset` was three axes and one of them was wrong.** The fallback anchors were `{x, y, z}`
   fractions of the bounding box with every point's x pinned at 0.5 and the barrel assumed to run
   along y. On the Special Carbine MK2 it runs along **x**, so all four points that fall back to an
   offset — barrel and skin always, magazine and flashlight when their bones do not resolve —
   landed at the same place along the gun and drew as one stack of overlapping labels on the
   receiver. It is `{ along, across, up }` now, and `measure()` resolves which axis `along` is (the
   longer of x and y) and which way it runs (from a nose bone: `gun_muzzle`, `WAPSupp`, `WAPFlsh`)
   once per weapon. Nothing to maintain per model, and a pistol reads the same as a sniper.
3. **One label at a time.** Even with the anchors right, seven captions on a metre of gun collide.
   The dot is always drawn; the name belongs to the point selected or under the cursor, and the
   rail's `All points` list is where all seven live with what is fitted to each. The dot also sits
   *on* its anchor now: the label used to be a flex sibling, so `translate(-50%)` centred the dot
   and the caption together and the dot ended up half a word to the left of the thing it marked.
4. **A cyan ring round the whole screen after an alt-tab.** `role="dialog"` needs a `tabindex` to
   satisfy `a11y_interactive_supports_focus`, and a `tabindex="-1"` element is focusable *by
   click* — so dragging the stage made this viewport-sized element the active one, and alt-tabbing
   back put Chromium in keyboard modality and drew `base.css`'s `:focus-visible` ring on it. It is
   a named `<section>` now: it stopped being a dialog when the bags stopped being behind it.
5. **One Escape did two things.** Every dialog here takes Escape on **keydown** and the window
   takes it on **keyup**, so a single press closed the attachments screen and then the inventory it
   had just returned to. `stopPropagation` in the dialog cannot reach that — it is a different
   event — and the dialogs' comments claiming "this is on top, so it wins" were true only of the
   keydown half. Worse, the two closes racing put a `TriggerScreenblurFadeIn` and a
   `TriggerScreenblurFadeOut` on the same frame and left the blur on an empty screen for the rest
   of the session. `Inventory.svelte` now latches the press where the ambiguity is: a dialog up at
   keydown spends the matching keyup. **`SettingsPanel` and `UsefulControls` were not covered** —
   they held their own `open` state inside `InventoryGrid` rather than in `lib/ui.svelte.ts`, so
   `dialogUp` could not see them and Escape on either closed the window underneath as well. They
   are `panels.help` and `panels.settings` in the store now. That is not a bigger store for its
   own sake: `ownPane` still decides which grid *mounts* them, and what it cannot decide is
   whether the window is allowed to know one is up. Moving them also closed a hole they had on
   their own — state owned by a pane outlived the window that raised it, so `dismissAll` never
   cleared them and reopening the bag could find a sheet still open. It clears them now.

**And the ordering that made the blur stick is gone as well.** `client.closeInventory` now calls
`Stage.stop(true)` itself, immediately before `Utils.blurOut()`, instead of waiting for the page's
`closeWeaponStage` to arrive a frame later on either side of it. `true` means *drop* the borrowed
hold rather than hand it back, so the count balances with no fade crossing another. The module's
old note — that watching the inventory from here would be a second answer to the same question —
was about *watching*; a call from the owner is the same answer with a known order.

**The player is out of the shot.** The weapon object floats three metres above the ped, which keeps
it out of the furniture and travels with the player, but the camera orbits and pitches and a shot
down onto the gun is a shot of the player standing under it. The ped is hidden locally while the
screen is up — a render flag on this client, the same thing `ghst_customs` does to the driver it is
sitting inside — and restored by `teardown`.

**Fitting a part no longer flashes.** A fit rebuilds the model, and the rebuild used to take the
camera and the ped's visibility with it: `RenderScriptCams(false)` and back, once per part, which
is a frame or two of the player's own gameplay camera and their own body. `teardown` now keeps both
when it is told a model is about to replace this one, and `Stage.start` reuses whatever survived.

**Fitting a part closed the screen, and the reason was two files away.** Components carry a
`usetime` -- 2500ms on most of them -- so `useItem` runs `lib.progressBar`, which sets
`LocalPlayer.state.invBusy` for its duration. `client.lua` mirrors that into a local through a
statebag handler, and the open-inventory watchdog runs `canOpenInventory()` every 100ms and closes
the window when it answers no. `invBusy` is one of the things it answers no to. So pressing `Fit`
put the player back in the world a tenth of a second later, before the part was even on the gun.

That rule is right for every ordinary item -- use a bandage from the bag and the bag should get out
of the way -- so it is not the rule that changed. `canOpenInventory` takes an `ignoreBusy` now, the
watchdog passes `Stage.isOpen()`, and every other reason still closes the window: death, cuffs, the
pause menu, walking away from a stash. The weapon timer is deliberately outside the exemption,
because that one moves when the player equips something, which *is* a reason to leave.

`Stage.isOpen` is a third piece of state and had to be: `slot` and `object` are both nil for the
frame or two a rebuild takes, and a watchdog that sampled either of those during a fit would close
the screen for the same reason with an extra step. It is written by the page's open and close and
by nothing in between.

**And `All points` was flush against the panel's edge** while every row under it was inset. The
caption takes `Row`'s whole leading box now -- `--row-pad-x` plus the transparent `border-left`
each row carries so the selected one can turn it into an accent bar -- rather than adding the two
widths up, because a raw pixel inside a padding is a spacing value off the scale and
`check-tokens.mjs` is right to refuse it.

**"The attachments only load after you have equipped the weapon once."** `RequestWeaponAsset`'s
last argument is `ExtraWeaponComponentFlags` and `ox_lib` defaults it to `0` —
`WEAPON_COMPONENT_NONE`. So the base weapon model streamed and not one component model came with
it: `GiveWeaponComponentToWeaponObject` succeeded, drew nothing, and the gun stood on the stage
bare while the rail correctly listed a scope, a suppressor, a barrel, a flashlight, a grip and an
extended clip as fitted. Equipping the weapon once was the workaround and also the tell — putting
the gun in the ped's hands makes the game load the components it is wearing, and they are still
resident when the screen next opens, so the fault looked like caching and was a request that never
asked. `stream()` passes `1|2|4|8|16` now, and issues the request *ahead of* the
`HasWeaponAssetLoaded` short-circuit: that native answers for the weapon, and a base model
something else already loaded answers true with no component models behind it.

**And the barrel went missing on an MK2 with no barrel upgrade.** `CreateWeaponObject`'s
`bCreateDefaultComponents` was `false`, on the reasoning that the gun should wear exactly what the
slot's metadata says and that a default clip added on top would draw a magazine nobody fitted. That
reads well and it is the wrong model of what a component is on an MK2 weapon: **the default barrel
is one.** So is the default clip and the default sight. They are not attachments the player chose —
they are the gun — and refusing them builds a rifle with no barrel on it. `data/weapons.lua` cannot
put it back either: it has an item only for `COMPONENT_AT_*_BARREL_02`, the heavy one, and none at
all for `_BARREL_01`, so there is no metadata entry that could name the standard barrel. It is
`true` now. Fitted parts still win, because GTA's component slots are mutually exclusive and the
extended clip replaces the default clip rather than sitting beside it.

**And the first report line came back, so the guessing is over.** On a Carbine Rifle MK2, in game
on 2026-09-08:

    weapon stage WEAPON_CARBINERIFLE_MK2 -- axis +x size 0.64/0.06/0.19
      -- bone: sight=WAPScop muzzle=WAPSupp flashlight=WAPFlshLasr grip=WAPGrip magazine=WAPClip
      | box: barrel skin

Four things, none of which was knowable from a screenshot:

1. **The long axis really is x**, solved at runtime, and the muzzle really is at `+x`. The
   axis-agnostic `frame` was not defensive coding; it was the answer.
2. **`WAPFlshLasr` is the flashlight bone and `WAPFlsh` is not.** The spelling this file shipped
   with never resolved on anything, so the flashlight dot had been falling back to the box since
   the day it was written — which is half of the label pile-up that started this.
3. **All five mount bones resolve**, so `barrel` and `skin` alone use the box. That is by design:
   neither names a bone in any GTA weapon model, and a paint job has nowhere else to sit than the
   receiver.
4. **`WAPSupp` won the muzzle** because it was first in the list, and `gun_muzzle` was behind it.
   They are not the same place: `WAPSupp` is where a suppressor *mounts*, which on a shrouded
   barrel is back under the handguard, and `gun_muzzle` is the end of the barrel. The point is
   called muzzle and a player looks for it at the sharp end, so the tip is tried first now.

The report line carries **where each dot landed** as well, as a fraction of the gun on the same
0-is-the-butt scale `POINTS` writes its fallbacks in — `muzzle=gun_muzzle@0.98`. A misplaced dot
stops being something to squint at in a screenshot and becomes a number to compare with the row
that produced it. A bone name is only ever a guess that the name means what it sounds like, and
whether a given mount sits where a player expects is per model and unknowable from here.

**Which bones resolve on which models is now REPORTED rather than guessed**, and the reason is a
retraction. This document said, on the strength of dot positions read off a screenshot, that
`WAPScop`/`WAPSupp`/`WAPGrip` resolved on the Special Carbine MK2 while `WAPClip`/`WAPFlsh` did
not. That was an inference, and it does not survive its own arithmetic: under the old offsets
`flashlight` sat at `z = 0.30` and `magazine` at `z = 0.00`, so a flashlight *falling back to the
box* had to draw above the magazine — and in the screenshot it drew below it. At least one of the
two was on a real bone. The weapon in that shot had both an extended clip and a tactical flashlight
fitted, which makes that the likely reading.

So `report()` prints one line per weapon per session naming, for every point, the bone that won or
the fact that it fell back to the box. `lib.print.info`, the same shape as the two other one-off
diagnostics in this resource. A dot in the wrong place looks exactly like a dot in the right place
until somebody who knows the weapon looks at it, and a bone name that hit and one that missed are
one console line apart and indistinguishable on screen.

The candidate lists are wider too, because a lookup costs a hash and being wrong costs a wrong dot:
`WAPScop_2`, `WAPSupp_2`, `WAPGrip_2`, `WAPClip_2`, and `WAPFlshLasr` — the flashlight mount is
usually written with the laser it shares, which is the spelling this file did not carry. There is
no way to shorten this to a fact from inside the game: `GetEntityBoneIndexByName` answers
name-to-index and GTA V has no index-to-name, so a model's bone list cannot be enumerated.

## Where the backlog lives

Planned UI work, and the facts behind each item, are in
`txData/ghst_sv/docs/inventory.md` rather than here. That document is server-level planning —
it covers what should be built and why — where this one covers what already differs from
upstream.
