# Berth

Pin named Hyprland workspaces to a physical monitor by model and serial, and show only that screen's occupied workspaces on the Omarchy bar.

The active workspace stays marked. Occupied workspaces stay listed. Empty ones stay hidden. Each name belongs to one monitor. The matcher reads the model inside Hyprland's monitor description and compares the serial. A serial of all zeros matches only another blank serial. The port name is not the identity.

Monitor position and resolution stay in your Hyprland monitor config. This file only decides which names belong to which panel.

## Install

```sh
omarchy plugin add https://github.com/Hamza-HM/berth.git
```

The workspace names and the setup control are separate bar items, so each can sit on its own side. Omarchy loads one widget from each plugin folder, and it refuses a link. Copy the setup widget, then enable both:

```sh
cp -a ~/.config/omarchy/plugins/hamza.berth/setup ~/.config/omarchy/plugins/hamza.berth.setup
omarchy-shell shell rescanPlugins
omarchy plugin enable hamza.berth --section left
omarchy plugin enable hamza.berth.setup --section right
```

After an update, copy that setup folder again before you reload the shell.

## Set up

Click the setup control. It is its own item on the bar, separate from the workspace names. Each connected screen is listed by its model. Show flashes that screen. Add as many names as you want, mark one as home, and save. A key is filled in from Numpad 1 onward. Click that key and press another to replace it, then save. Past the tenth name, a workspace with no key stays on the bar and is opened with a click.

If the keys are not installed yet, the panel can add one line to `~/.config/hypr/bindings.lua`. That line loads `hyprland.lua`. Your other bindings stay as they are.

## Layout

The panel writes `~/.config/omarchy/plugins/hamza.berth/layout.json`. You can edit that file instead. The bar and the keybindings both read it.

`model` must appear in the description printed by `hyprctl monitors`. `serial` must match that monitor. `home` is the workspace the monitor opens on. `key` is a Hyprland key name, usually a numpad keycode such as `code:87`. `make` is a note for you. The matcher does not use it.

Two identical panels stay unpinned unless an entry sets `connector` to the port it was bound to. An unknown monitor shows only workspaces that currently have windows. While a matched panel is unplugged, its names stay off the other bars.

## Keybindings

Add the contents of `examples/bindings.lua` to `~/.config/hypr/bindings.lua`, then run `hyprctl reload`.

Omarchy already binds Super+1 and Super+2. The snippet removes those binds only when the layout uses `code:10` or `code:11`.

## Remove

```sh
omarchy plugin remove hamza.berth.setup
omarchy plugin remove hamza.berth
```

Remove the setup widget first. Each command asks before it disables that widget and deletes its folder. Removing Berth also deletes `layout.json`. Delete the Berth lines from `~/.config/hypr/bindings.lua` yourself, then run `hyprctl reload`. Monitor position and resolution are left as they are.

## Dependencies

Berth runs inside Omarchy. It uses the Hyprland tools that ship with Omarchy and installs no other packages.

## License

MIT. See [LICENSE](LICENSE).
