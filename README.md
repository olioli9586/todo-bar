# TodoBar

A tiny macOS menu bar todo list. Same lightweight setup as the `widget` project — Swift Package Manager only, no Xcode required.

- Click the checklist icon in the menu bar (shows how many todos are left)
- Type in the field and press Enter to add a todo
- Click the circle to check a todo off; hover a row and click ✕ to remove it
- "Clear Done" removes everything checked off
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
