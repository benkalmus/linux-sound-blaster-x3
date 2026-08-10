#!/usr/bin/python3
"""Headless BlueZ agent that auto-accepts speaker pair/connection requests.

Runs as a persistent D-Bus agent with NoInputNoOutput capability so a phone
can pair and connect to this PC without any on-screen confirmation.
"""

import argparse
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS_NAME = "org.bluez"
AGENT_INTERFACE = "org.bluez.Agent1"
AGENT_PATH = "/org/bluez/autoagent"

A2DP_SINK = "0000110b-0000-1000-8000-00805f9b34fb"
A2DP_SOURCE = "0000110a-0000-1000-8000-00805f9b34fb"
AVRCP_REMOTE = "0000110e-0000-1000-8000-00805f9b34fb"
AVRCP_TARGET = "0000110c-0000-1000-8000-00805f9b34fb"
BAP_SINK = "00002f00-0000-1000-8000-00805f9b34fb"
BAP_SOURCE = "00002f01-0000-1000-8000-00805f9b34fb"

ALLOWED_SERVICES = {
    A2DP_SINK,
    A2DP_SOURCE,
    AVRCP_REMOTE,
    AVRCP_TARGET,
    BAP_SINK,
    BAP_SOURCE,
}


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Agent(dbus.service.Object):
    def __init__(self, bus, path, single_connection=False):
        self._single = single_connection
        self._connected_device = None
        self._exit_on_release = True
        dbus.service.Object.__init__(self, bus, path)

        if single_connection:
            bus.add_signal_receiver(
                self._properties_changed,
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                bus_name="org.bluez",
                arg0="org.bluez.Device1",
                path_keyword="path",
            )

    def set_exit_on_release(self, value):
        self._exit_on_release = value

    def _properties_changed(self, interface, changed, invalidated, path=None):
        connected = changed.get("Connected") if isinstance(changed, dict) else None
        if connected is None:
            return

        if not self._connected_device and connected:
            self._connected_device = path
            print(f"Single-mode: {path} connected")
        elif path == self._connected_device and not connected:
            self._connected_device = None
            print(f"Single-mode: {path} disconnected")

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        print("Agent released")
        if self._exit_on_release:
            GLib.MainLoop().quit()

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        if self._single and self._connected_device and self._connected_device != device:
            print(f"Reject {device}: another device already connected")
            raise Rejected("Only one connection allowed")

        if uuid in ALLOWED_SERVICES:
            print(f"AuthorizeService {device} {uuid}")
            self._trust_device(device)
            return

        print(f"Reject service {device} {uuid}")
        raise Rejected("Service not allowed")

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print(f"RequestPinCode {device}: returning 0000")
        self._trust_device(device)
        return "0000"

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        print(f"RequestPasskey {device}: returning 0")
        self._trust_device(device)
        return dbus.UInt32(0)

    @dbus.service.method(AGENT_INTERFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print(f"DisplayPasskey {device} {passkey:06d} entered={entered}")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        print(f"DisplayPinCode {device} {pincode}")

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print(f"RequestConfirmation {device} {passkey:06d}: auto-accept")
        self._trust_device(device)

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print(f"RequestAuthorization {device}: auto-accept")
        self._trust_device(device)

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancel")

    def _trust_device(self, device_path):
        try:
            dev = dbus.Interface(
                self.connection.get_object(BUS_NAME, device_path),
                "org.freedesktop.DBus.Properties",
            )
            dev.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
        except dbus.DBusException as exc:
            print(f"Could not trust {device_path}: {exc}")


def _find_adapter(bus, preferred="hci0"):
    om = dbus.Interface(
        bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager"
    )
    objects = om.GetManagedObjects()
    for path, ifaces in objects.items():
        if "org.bluez.Adapter1" in ifaces:
            if path == f"/org/bluez/{preferred}" or preferred is None:
                return path
    for path, ifaces in objects.items():
        if "org.bluez.Adapter1" in ifaces:
            return path
    return None


def configure_adapter(bus, adapter_arg):
    adapter_path = adapter_arg if adapter_arg and adapter_arg.startswith("/") else None
    if adapter_path is None:
        adapter_path = _find_adapter(bus, adapter_arg or "hci0")

    if not adapter_path:
        raise RuntimeError("No Bluetooth adapter found")

    print(f"Using adapter {adapter_path}")
    adapter = dbus.Interface(
        bus.get_object(BUS_NAME, adapter_path), "org.freedesktop.DBus.Properties"
    )

    adapter.Set("org.bluez.Adapter1", "DiscoverableTimeout", dbus.UInt32(0))
    adapter.Set("org.bluez.Adapter1", "Discoverable", dbus.Boolean(True))
    adapter.Set("org.bluez.Adapter1", "Pairable", dbus.Boolean(True))
    adapter.Set("org.bluez.Adapter1", "PairableTimeout", dbus.UInt32(0))

    return adapter_path


def register_agent(bus, agent, manager):
    try:
        manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
        print("Agent registered with NoInputNoOutput")
    except dbus.DBusException as exc:
        print(f"RegisterAgent failed: {exc}", file=sys.stderr)
        return False

    try:
        manager.RequestDefaultAgent(AGENT_PATH)
        print("Default agent set")
    except dbus.DBusException as exc:
        print(f"RequestDefaultAgent failed: {exc}", file=sys.stderr)
        return False

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Headless auto-accept BlueZ speaker agent"
    )
    parser.add_argument(
        "-i", "--adapter", default="hci0", help="Adapter name or path (default: hci0)"
    )
    parser.add_argument(
        "--single-connection",
        action="store_true",
        help="Allow only one connected device at a time",
    )
    args = parser.parse_args()

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    agent = Agent(bus, AGENT_PATH, args.single_connection)
    agent.set_exit_on_release(False)

    def on_name_owner_changed(name, old_owner, new_owner):
        if name != "org.bluez":
            return
        if not new_owner:
            print("Bluetooth daemon went away")
            return
        print("Bluetooth daemon appeared")
        try:
            configure_adapter(bus, args.adapter)
        except Exception as exc:
            print(f"Adapter config warning: {exc}", file=sys.stderr)

        manager = dbus.Interface(
            bus.get_object(BUS_NAME, "/org/bluez"), "org.bluez.AgentManager1"
        )
        register_agent(bus, agent, manager)

    bus.add_signal_receiver(
        on_name_owner_changed,
        signal_name="NameOwnerChanged",
        dbus_interface="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        arg0="org.bluez",
    )

    dbus_obj = bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
    dbus_iface = dbus.Interface(dbus_obj, "org.freedesktop.DBus")
    if dbus_iface.NameHasOwner("org.bluez"):
        on_name_owner_changed("org.bluez", "", dbus_iface.GetNameOwner("org.bluez"))
    else:
        print("Waiting for Bluetooth daemon...")

    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
