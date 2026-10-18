# Status previews

From the repository root, run the standalone offscreen renderer:

```sh
swift scripts/render-status.swift
```

If a sandbox blocks Swift's default compiler cache, use
`swift -module-cache-path .build/status-module-cache scripts/render-status.swift`.

An optional output directory can be passed to `swift scripts/render-status.swift <directory>`.
The executable script `./scripts/render-status.swift` also works. It compiles the
shared production helpers and `scripts/StatusRenderer.swift` into `.build` before
running the renderer. The renderer uses AppKit bitmap graphics only: it does not create an application,
window, menu bar item, event tap, or permission prompt.

Every state has a menu bar preview on light and dark backgrounds (80 × 48 pixels)
and an English and Japanese menu status preview in each appearance (560 × 152 pixels).
All images are rendered at 2× using the production symbol and text styling helpers.
The menu section is a static layout mock; native menu spacing, material, hover, and
disabled-item rendering can differ. These are not screenshots of a running app.

File names are `<state>-menubar-<light|dark>@2x.png` and
`<state>-menu-<en|ja>-<light|dark>@2x.png`, where state is `watching`,
`permissionNeeded`, `paused`, `stopped`, or `tapError`.
