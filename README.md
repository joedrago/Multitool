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
| `/tool shards N` | Deletes all but N Soul Shards (outside the soul bag first) and moves the rest into your soul bag. The game allows one delete per key press, so trimming several shards takes several presses. Does nothing in combat, so it's safe to put in a macro you press often. |
| `/tool targetcast [X Y \| reset]` | With no arguments, prints where the target's cast bar is. With `X Y`, pins its center at that offset from the screen center and keeps it there. `reset` returns it to Blizzard's placement. Stored account-wide. |

`/tool init` does the following:

- Switches to your UI Layout (Edit Mode).
- Sets which messages go to the General and Combat Log tabs, sets chat colors, and gives both windows an opaque black background.
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
