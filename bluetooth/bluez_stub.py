"""Stub BlueZ daemon for the agent harness.

Owns org.bluez on a private bus, records every call to STUB_LOG, and can
trigger the three Agent1 pairing requests or refuse agent registration.
"""

import os
from typing import Any

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib  # pyright: ignore[reportAttributeAccessIssue]

LOG = os.environ["STUB_LOG"]
DEVICE_PATH = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
A2DP_SINK = "0000110b-0000-1000-8000-00805f9b34fb"

STATE_BUS: Any = None
STATE_AGENT_NAME: Any = None
STATE_AGENT_PATH: Any = None
NAME_HANDLE: Any = None


def record(line):
    with open(LOG, "a") as handle:
        handle.write(line + "\n")


class Properties(dbus.service.Object):
    @dbus.service.method(
        "org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v"
    )
    def Get(self, interface, name):
        record(f"Get {interface} {name}")
        if name == "Trusted":
            return dbus.Boolean(False)
        return dbus.UInt32(0)

    @dbus.service.method(
        "org.freedesktop.DBus.Properties", in_signature="ssv", out_signature=""
    )
    def Set(self, interface, name, value):
        record(f"Set {interface} {name} {value}")


class Device(Properties):
    pass


class ManagedObjects(dbus.service.Object):
    @dbus.service.method(
        "org.freedesktop.DBus.ObjectManager",
        in_signature="",
        out_signature="a{oa{sa{sv}}}",
    )
    def GetManagedObjects(self):
        return {
            "/org/bluez/hci0": {"org.bluez.Adapter1": {}},
            DEVICE_PATH: {"org.bluez.Device1": {}},
        }


class AgentManager(dbus.service.Object):
    @dbus.service.method(
        "org.bluez.AgentManager1",
        in_signature="os",
        out_signature="",
        sender_keyword="sender",
    )
    def RegisterAgent(self, path, capability, sender=None):
        global STATE_AGENT_NAME, STATE_AGENT_PATH
        record(f"RegisterAgent {path} {capability}")
        if os.environ.get("STUB_FAIL_REGISTER"):
            raise dbus.DBusException(
                "Registration refused for test", name="org.bluez.Error.Failed"
            )
        STATE_AGENT_NAME = sender
        STATE_AGENT_PATH = path
        if os.environ.get("STUB_TRIGGER_PAIRING"):
            GLib.timeout_add(500, request_pairing)

    @dbus.service.method("org.bluez.AgentManager1", in_signature="o", out_signature="")
    def RequestDefaultAgent(self, path):
        record(f"RequestDefaultAgent {path}")


def request_pairing():
    agent = dbus.Interface(
        STATE_BUS.get_object(STATE_AGENT_NAME, STATE_AGENT_PATH),
        "org.bluez.Agent1",
    )
    device = dbus.ObjectPath(DEVICE_PATH)
    calls = [
        ("RequestConfirmation", "ou", (device, dbus.UInt32(123456))),
        ("RequestAuthorization", "o", (device,)),
        ("AuthorizeService", "os", (device, A2DP_SINK)),
    ]

    def run_next():
        if not calls:
            return
        name, signature, args = calls.pop(0)
        method = agent.get_dbus_method(name)
        method(
            *args,
            signature=signature,
            reply_handler=lambda *_: (record(f"{name} accepted"), run_next()),
            error_handler=lambda exc: (
                record(f"{name} FAILED {exc.get_dbus_name()}"),
                run_next(),
            ),
        )

    run_next()
    return False


def main():
    global NAME_HANDLE, STATE_BUS
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    STATE_BUS = dbus.SystemBus()
    # The name handle must outlive main(), otherwise the bus name is released.
    NAME_HANDLE = dbus.service.BusName("org.bluez", STATE_BUS)
    ManagedObjects(STATE_BUS, "/")
    AgentManager(STATE_BUS, "/org/bluez")
    Properties(STATE_BUS, "/org/bluez/hci0")
    Device(STATE_BUS, DEVICE_PATH)
    print("stub ready", flush=True)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
