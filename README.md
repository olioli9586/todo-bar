# TodoBar

A tiny macOS menu bar todo list. Same lightweight setup as the `widget` project — Swift Package Manager only, no Xcode required.

- Click the checklist icon in the menu bar (shows how many todos are left), or press **⌥T** from any app
- Type in the field and press Enter to add a todo (the field is focused as soon as the panel opens)
- Click the circle to check a todo off; hover a row and click ✕ to remove it
- **Double-click** a todo to edit its text (Enter saves, Esc cancels)
- **Drag** rows to reorder them
- The list grows to fit everything; it only scrolls if it would run past the screen
- **Daily reset**: on the first use each new day, checked-off items are cleared automatically
- "Clear Done" removes everything checked off right away
- Todos persist in `~/Library/Application Support/TodoBar/todos.json`

## Build & install

```sh
make install   # builds, bundles TodoBar.app, copies to /Applications, launches it
```

Other targets:

```sh
make build    # swift build -c release
make bundle   # build + create dist/TodoBar.app
make run      # bundle + run in the foreground
make clean    # remove .build and dist
```
