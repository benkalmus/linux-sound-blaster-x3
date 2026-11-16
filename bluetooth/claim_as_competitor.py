"""Claim the BlueZ default agent the way bluedevil does, for the harness."""

import dbus

COMPETITOR_PATH = "/modules/bluedevil/Agent"


def main():
    bus = dbus.SystemBus()
    manager = dbus.Interface(
        bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1"
    )
    manager.RequestDefaultAgent(COMPETITOR_PATH, signature="o")
    print(f"competitor claimed {COMPETITOR_PATH}")


if __name__ == "__main__":
    main()
