# Berth

Pin named Hyprland workspaces to a physical monitor by model and serial, and show only that screen's occupied workspaces on the Omarchy bar.

The active workspace stays marked. Occupied workspaces stay listed. Empty ones stay hidden. Each name belongs to one monitor. The matcher reads the model inside Hyprland's monitor description and compares the serial. A serial of all zeros matches only another blank serial. The port name is not the identity.

Monitor position and resolution stay in your Hyprland monitor config. This file only decides which names belong to which panel.

## Install

```sh
omarchy plugin add https://github.com/Hamza-HM/berth.git
```

Enable it on the left of the bar when asked, or later:

```sh
omarchy plugin enable hamza.berth --section left
```

## Layout

Copy `layout.example.json` to `~/.config/omarchy/plugins/hamza.berth/layout.json`. The bar and the keybindings both read that file.

`model` must appear in the description printed by `hyprctl monitors`. `serial` must match that monitor. `home` is the workspace the monitor opens on. `key` is a Hyprland key name, usually a numpad keycode such as `code:87`. `make` is a note for you. The matcher does not use it.

Two identical panels stay unpinned unless an entry sets `connector` to the port it was bound to. An unknown monitor shows only workspaces that currently have windows. While a matched panel is unplugged, its names stay off the other bars.

## Keybindings

Add the contents of `examples/bindings.lua` to `~/.config/hypr/bindings.lua`, then run `hyprctl reload`.

Omarchy already binds Super+1 and Super+2. The snippet removes those binds only when the layout uses `code:10` or `code:11`.

## License

MIT. See [LICENSE](LICENSE).
