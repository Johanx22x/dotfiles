// Who and where: the handful of facts the settings window shows about the
// session itself.
//
// ALL OF IT IS READ ONCE. None of these change while the shell is up -- the
// user does not get renamed, the kernel does not get swapped underneath a
// running system -- so there is no watcher and no timer here. The one
// exception is the uptime, which is read on demand rather than counted, so
// the number is right whenever it is looked at without anything ticking in
// the background for the 99% of the time the window is closed.
//
// WHY /etc/os-release AND NOT fastfetch OR lsb_release. It is a file, it is
// specified, and reading it costs no process. `fastfetch` is installed and
// would answer prettier, but spawning a program to learn the name of the
// distribution is the kind of thing that turns a window into a load average.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string shell: {
        const path = Quickshell.env("SHELL") || "";
        return path.split("/").pop() || "unknown";
    }

    property string host: "localhost"
    property string distro: "Linux"
    property string kernel: ""

    // The GECOS full name if there is one, the username otherwise. There is
    // no full name on this machine -- the field in /etc/passwd is empty --
    // which is exactly the case this fallback exists for, rather than showing
    // a blank line where a name should be.
    readonly property string displayName: root.fullName !== "" ? root.fullName : root.user

    property string fullName: ""

    // Seconds since boot, straight out of /proc/uptime's first field.
    function uptimeSeconds(): int {
        // Re-read on the spot. A FileView loads asynchronously, so the first
        // caller after startup would otherwise get an empty string and be
        // told the machine had been up for zero minutes -- which is what it
        // said until blockLoading was added below.
        uptimeFile.reload();
        const text = uptimeFile.text();
        if (!text)
            return 0;
        return Math.floor(parseFloat(text.split(" ")[0]) || 0);
    }

    // "3d 4h", "4h 12m", "12m". Two units at most: the third is never the
    // reason anyone is reading it.
    function uptime(): string {
        const total = root.uptimeSeconds();
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);

        if (days > 0)
            return `${days}d ${hours}h`;
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        // Read synchronously: it is 30 bytes of procfs and the caller wants
        // the answer in the same expression it asked in.
        blockLoading: true
        // NOT watched. /proc/uptime changes every tick, and a watcher on it
        // would wake the shell a hundred times a second to learn something
        // nobody is looking at.
        printErrors: false
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.host = text().trim() || "localhost"
    }

    FileView {
        path: "/proc/sys/kernel/osrelease"
        printErrors: false
        onLoaded: root.kernel = text().trim()
    }

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            // PRETTY_NAME, quoted, one key per line. Parsed rather than
            // matched loosely: NAME is also in there and is the shorter,
            // duller answer ("Arch Linux" against "Arch Linux").
            for (const line of text().split("\n")) {
                if (!line.startsWith("PRETTY_NAME="))
                    continue;
                root.distro = line.slice("PRETTY_NAME=".length).replace(/^"|"$/g, "");
                return;
            }
        }
    }

    // The full name, if the passwd entry carries one. GECOS is the fifth
    // colon-separated field and its first comma-separated part.
    Process {
        running: true
        command: ["getent", "passwd", root.user]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(":");
                if (fields.length < 5)
                    return;
                root.fullName = (fields[4] || "").split(",")[0].trim();
            }
        }
    }
}
