# Changelog

Each version's notes, newest first. The release on GitHub is built from the section with its number.

## 0.2.2 — 2026-11-19

- **Click again to scroll again**: a click ends a scroll. If you're still holding Win + Ctrl, the next click now starts a new one where you click, like a browser's middle-click scroll. Before, nothing happened until you let go of the keys.
- **Fixed**: a key could fire when other keys were held as well, after another app (or Global Scroller itself) had hidden them. A click key now counts only when no other Ctrl, Alt, Shift or Win is really held.
- **Fixed**: a touch-drag click on text that didn't move (in Firefox, on a word) could set off a chain of clicks — the word was selected and clicked over and over until you let go of the keys. Windows turns the made-up finger's tap into a click, and that click was taken for yours. Now only a click you really make counts.
- **Fixed**: after Global Scroller had run for a day or so, the round scroll mark could appear behind the window you scroll. It now comes to the front every time.

## 0.2.1 — 2026-11-14

- **New keys, on the left click**: **Win + Ctrl + click** scrolls, **Win + Shift + click** is touch drag. With a pen, a touch of the tip is enough now. If you never changed your keys, these replace the old right-click ones. The old ones still work if you set them in Settings > Keys.
- **Clearer update message**: when GitHub has had too many questions from your connection in the last hour, the update check now says so, instead of "Could not reach GitHub (HTTP 403)".
- **Fixed**: "Update now" could refuse to finish in some folders; it now works wherever the app is.

## 0.2.0 — 2026-11-14

The first public version.

- **Scroll by moving the mouse**: Win + Shift + right-click puts a mark down; move away from it and the window scrolls that way, faster the further you go.
- **Hold or tap**: keep the keys held to scroll while you hold, or let go right away and it stays on until a click.
- **Smooth wheel**: the same scrolling in steps five times smaller, for a page that glides.
- **Touch drag** (experimental): hold Win + Alt, and every right-click-drag drags the page like a finger.
- **Settings in a window**, dark or light; both keys can be changed.

<details>
<summary><b>More</b> (4)</summary>

- While you hold the keys, other programs don't see them, so Shift + wheel or Alt + wheel shortcuts don't fire by accident.
- Start with Windows, and Run as administrator for programs that run as administrator themselves - both in the tray menu.
- Once a day it asks GitHub whether there's a newer version; **Update now** installs it and keeps your settings. Nothing installs without your click.
- It runs as its own `Global-Scroller.exe` (made beside the script at the first start), so it has its own icon in the tray and in Task Manager.

</details>
