# groff-preview.nvim

Live PDF preview for groff documents (`.ms`, `.mom`, `.me`, `.mm`) in Neovim.
Run `:GroffPreview` once; after that every `:w` rebuilds the PDF and the viewer
reloads it, keeping your page and zoom.

Made for Neovim in WSL on Windows, but the pane viewer also works in tmux and
WezTerm on Linux, and any OS falls back to the system PDF viewer.

## Viewers

| Viewer | Where | What you get |
|---|---|---|
| `sumatra` | WSL | SumatraPDF opens and is **tiled beside the terminal window** like a split; focus returns to Neovim |
| `pane` | WezTerm, Windows Terminal, tmux | A terminal split next to Neovim showing the page. Sharp in WezTerm (mouse scroll, Ctrl+wheel zoom); lower-resolution sixel in Windows Terminal and tmux |
| `system` | anywhere | Your default PDF viewer (`vim.ui.open`) |
| `auto` (default) | | `pane` in WezTerm, otherwise `sumatra` if installed, otherwise `pane` if a split is possible, otherwise `system` |

Pick per call with `:GroffPreview pane`, or set a default (see below).

## Requirements

- Neovim 0.10+
- groff (`groff`, and `pdfmom` for `.mom`)
- Pane viewer: `pdftoppm`/`pdfinfo` (poppler-utils), ImageMagick 7 (`magick`, `identify`)
- SumatraPDF route: SumatraPDF on Windows, PowerShell (comes with Windows)

Debian/Ubuntu: `sudo apt install groff poppler-utils imagemagick`

## Install

lazy.nvim:

```lua
{
  "rayhanasyraff/groff-preview.nvim",
  cmd = "GroffPreview",
  opts = {},
}
```

## Configuration

Defaults:

```lua
opts = {
  viewer = "auto",          -- "auto" | "pane" | "sumatra" | "system"
  ratio = 0.55,             -- SumatraPDF: share of the screen width kept for the terminal
  pane_size = 40,           -- pane viewer: percent of the window
  pane_position = "right",  -- or "bottom"
  sumatra = nil,            -- path to SumatraPDF.exe; nil = auto-detect
  wezterm = nil,            -- path to wezterm / wezterm.exe; nil = auto-detect
  commands = {              -- "$1" = source file, "$2" = output PDF
    mom = 'pdfmom -k -t -e -p -P-e "$1" > "$2"',
    me = 'groff -me -k -t -e -p -Tpdf -P-e "$1" > "$2"',
    mm = 'groff -mm -k -t -e -p -Tpdf -P-e "$1" > "$2"',
    default = 'groff -ms -k -t -e -p -Tpdf -P-e "$1" > "$2"',
  },
}
```

`vim.g.groff_preview_viewer` and `vim.g.groff_preview_ratio` override `viewer`
and `ratio` if set. The build flags: `-k` UTF-8 input, `-t -e -p` tbl/eqn/pic,
`-P-e` embeds all fonts.

## Pane viewer keys

| Key | Action |
|---|---|
| `n` / `p`, PgDn / PgUp | next / previous page |
| mouse wheel, `j` / `k` | scroll (continues onto the next page) — WezTerm |
| Ctrl + wheel, `+` / `-` | zoom at the pointer — WezTerm |
| Alt + wheel, `h` / `l` | scroll sideways — WezTerm |
| `z` | fit page / fit width — WezTerm |
| `g` / `G` | top / bottom of page — WezTerm |
| `r` | redraw |
| `q` | close |

The pane closes by itself when the Neovim that opened it exits. Tune the
pixel math with `GROFF_PREVIEW_CELL_W`, `GROFF_PREVIEW_CELL_H` (sixel) and
`GROFF_PREVIEW_CELL_RATIO` (WezTerm) if pages look stretched.

## Standalone viewer

`bin/groff-preview file.ms` previews without Neovim: it watches the file,
rebuilds on change and shows the page as sixel in the terminal
(`n`/`p` page, `+`/`-` zoom, `h`/`j`/`k`/`l` pan, `q` quit).
Needs `img2sixel` (libsixel) and ImageMagick's `convert`.

## Credits

The pane viewer started as a patch to
[glimpse.nvim](https://github.com/adriancmiranda/glimpse.nvim).
