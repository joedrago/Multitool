# Multitool

Assorted QoL slash commands for WoW Forever. `/tool` lists them all.

## Commands

| Command | What it does |
| --- | --- |
| `/tool ranks` (also `/fixranks`, `/fr`) | Replaces every spell on your action bars with the highest rank you know. Add `debug` for a verbose scan. |
| `/tool init [LayoutName]` | Sets up the current character the way I like it, then reloads the UI. Safe to run repeatedly. The layout name is remembered after the first run. |
| `/tool savechatpos` | Remembers the position and size of every undocked chat window (e.g. Combat Log) for `/tool init`. |
| `/tool snapshot save` | Captures account-wide settings, key bindings and UI layouts into Multitool's saved variables. |
| `/tool snapshot restore` | Applies a saved snapshot to the current install. |
| `/tool shards N` | Deletes all but N Soul Shards (outside the soul bag first) and moves the rest into your soul bag. N is raised to your soul bag's size if it's smaller, so a full soul bag is never trimmed. The game allows one delete per key press, so trimming several shards takes several presses. Does nothing in combat, so it's safe to put in a macro you press often. |
| `/tool targetcast [X Y \| reset]` | With no arguments, prints where the target's cast bar is. With `X Y`, pins its center at that offset from the screen center and keeps it there. `reset` returns it to Blizzard's placement. Stored account-wide. |
| `/tool chat [N]` | Sets the background opacity of the General and Combat Log windows, from `0` to `1` (default `0.5`). Applies right away and is used by `/tool init`. Stored account-wide. |
| `/tool fade [N]` | Fades most of the UI after N seconds of not using it. `0` turns it off (the default). With no arguments, prints the current settings. See [Fade](#fade) below. |
| `/tool fade combat on\|off` | Whether entering combat brings everything back (default `on`). With `off`, only hovering does. |
| `/tool fade minimap N` | How far the minimap fades, from `0` (gone, the default) to `1` (not at all). |
| `/tool fade main N` | How far the main action bar fades, from `0` (gone, the default) to `1` (not at all). |
| `/tool fade unit N` | How far the player and target frames fade while they still matter, from `0` to `1` (default `0.5`). |
| `/tool fade damage N` | How far the damage meter fades while you're in a group, from `0` (gone, the default) to `1` (not at all). Solo, it always fades out completely. |
| `/tool fade chat N` | How far the main chat window's text fades, from `0` (gone) to `1` (not at all). Default `0.5`. Its background always fades away completely. |
| `/tool fade xp N` | How far the experience bar fades for N seconds (your fade delay) after gaining XP, from `0` (gone, the default) to `1` (not at all). |

`/tool init` does the following:

- Switches to your UI Layout (Edit Mode).
- Sets which messages go to the General and Combat Log tabs, sets chat colors, and gives both windows a black background at your `/tool chat` opacity.
- Unchecks all numbered chat channels (General, Trade, ...) in every window. You stay in the channels.
- Turns on action bars 2-8.
- Turns on Power Bars on raid frames.
- Turns on the built-in damage meter.
- Moves Target / Open Context Menu click bindings to Shift+Left / Shift+Right, for Click Casting.
- Restores saved chat window positions (`/tool savechatpos`).
- Turns on the chat tweaks below and sets chat style to Classic.

Chat tweaks, re-applied every login once enabled:

- The input box sits above each chat window.
- Chat windows can be resized smaller and placed flush against the screen edge.
- Chat tabs stay hidden until you mouse over the window or a tab starts flashing.

## Fade

With `/tool fade N` set, each piece of the UI fades out once you've left it alone for N seconds. Hovering a piece brings it back, and starts its clock over when the mouse leaves. Entering combat (unless `/tool fade combat off`) or opening Edit Mode brings everything back. Faded pieces still take clicks.

Each of these fades on its own:

- **Minimap**, with its zone text, border and buttons. At `/tool fade minimap 0` the map is hidden once fully faded, because the player arrow and tracking icons ignore transparency.
- **Main chat window** (General and anything docked with it). Only its background, border and buttons fade away. The text dims to the `/tool fade chat` level (half by default), and typing brings it back.
- **Other chat windows** (undocked, e.g. a separate Combat Log). These fade entirely.
- **Main action bar**. Stops at the `/tool fade main` level.
- **Other action bars**. Hovering any bar, the main one included, brings back all of them.
- **Player frame and personal resource display**. Stop at the `/tool fade unit` level while you're in combat, or while your health or main power bar has changed in the last 7 seconds. The game keeps those values secret from addons, so "still changing" is the best available stand-in for "not full".
- **Target frame**. Stops at the `/tool fade unit` level while you're in combat, or for 5 seconds after picking a target.
- **Other unit frames**: focus, party and raid frames. Hovering any unit frame, player and target included, brings back all of them.
- **Damage meter**. Stops at the `/tool fade damage` level while you're in a group.
- **Bag buttons**.
- **Menu buttons** (character, spellbook, ...).
- **Experience and reputation bars**. Stop at the `/tool fade xp` level for your fade delay after gaining XP.
- **Quest tracker**.
- **Buffs and debuffs**.

Opacity set in Edit Mode is kept: a frame fades down from its own opacity and returns to it.

## Moving to a fresh install

`/tool init` handles per-character setup. A brand-new WoW install also loses account-wide state: settings, key bindings and UI layouts. `/tool snapshot` carries that across.

### Before leaving the old install

1. `/tool snapshot save`
2. `/reload` or log out. Saved variables are only written to disk at that point.
3. Back up the old install's `WTF` folder (zip it). The important file is
   `WTF\Account\<ACCOUNT>\SavedVariables\Multitool.lua`.
   Keep the whole folder anyway: it also has macros and other addons' settings.

### On the new install

1. Install Multitool into `Interface\AddOns`.
2. Launch once and log in to any character, so the `WTF\Account\<ACCOUNT>` folder gets created. Then quit.
3. Copy the backed-up `SavedVariables\Multitool.lua` into the new install's `WTF\Account\<ACCOUNT>\SavedVariables\`.
4. Log in, then `/tool snapshot restore`, `/reload`, and `/tool init`.

### What a snapshot contains

- **Settings:** every console variable (CVar) you've changed from its default, except per-character ones and a few install-specific ones (last realm, account name, locale, cache counters, hardware survey).
- **Key bindings:** the full set. Restoring replaces your current bindings.
- **UI Layouts:** every saved Edit Mode layout, imported as an account layout. Layouts that already exist by name are skipped.
- **Edit Mode account settings.**

Anything the game won't let an addon change is listed in red after a restore. Macros and other addons' settings aren't in the snapshot; copy those from the `WTF` backup.
