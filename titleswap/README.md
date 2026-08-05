# Titleswap
Swaps titles.

You can drag the panel around, it will save its position between sessions.

Use the small `?` button at the top-right to open the settings window. The window shows each saved title and its nickname. Select a title and press `X` to remove it, use `^` and `v` to reorder it, edit a nickname directly, or press `Add` to save the currently active title.

The `Show icons` button switches the main panel between the compact icon layout and the original full-width title buttons. This preference is saved between sessions.

TitleSwap verifies every change after 500 ms. If the game did not apply it, the requested button turns red and `Title swap failed.` is printed to chat; the title that is actually active remains green.

/addtitle <name(OPTIONAL)>
Adds your current title to the list.

/removetitle <name(OPTIONAL)>
Removes your current title, or the one you put in 'name' if you use that.

![Titleswap example](https://i.imgur.com/OcIq9la.png)
