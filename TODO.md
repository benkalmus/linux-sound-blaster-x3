# TODO

- Remove the redundant SDDM WirePlumber drop-ins after the sddm audio mask is proven across a reboot.
  - `configs/51-sddm-no-alsa.conf`
  - `configs/51-sddm-no-bluetooth.conf`
- Copy `/etc/bluetooth/main.conf` instead of symlinking it. `bluetoothd` runs as the `bluetooth` user and cannot traverse `/home/benkalmus`.
- Copy `/etc/pipewire/pipewire-pulse.conf.d/upmix.conf` and `/etc/pipewire/client.conf.d/upmix.conf` instead of symlinking them. SDDM's PipeWire and KWin cannot traverse `/home/benkalmus`.
- Add automatic one-user-at-a-time handoff for rdp. When another user's session becomes active, stop the benkalmus audio stack. When benkalmus is active, start it again.
- Make `revert-host` remove the sddm masks when the sddm user manager is down. The primary mask uses `systemctl --user unmask`, which needs the manager.
