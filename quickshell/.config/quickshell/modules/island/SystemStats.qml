// What the machine is doing, for the dashboard's Performance tab.
//
// WHERE EACH NUMBER COMES FROM, and why they are not all the same way:
//
//   CPU load, memory, frequency   /proc, read directly. These are files the
//                                 kernel already keeps up to date; running
//                                 `top` or `free` on a timer would only be
//                                 asking another program to read them for us.
//   CPU temperature               /sys/class/hwmon, but the path is DISCOVERED
//                                 rather than written down. See below.
//   GPU                           nvidia-smi. There is no sysfs equivalent for
//                                 an NVIDIA card -- utilisation, VRAM and
//                                 power all come out of the driver's own tool,
//                                 so this is the one reading that costs a
//                                 process.
//
// EVERYTHING IS GATED ON `active`. The Performance tab sets it while it is on
// screen and clears it when the popout closes, so nothing here polls /proc or
// holds nvidia-smi open while nobody is looking at the numbers.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Set by the Performance tab. Nothing samples while this is false.
    property bool active: false

    readonly property int sampleInterval: 2000

    // ---------------- CPU ----------------
    property string cpuModel: ""
    property real cpuPercent: 0
    property real cpuTemp: 0
    property real cpuFreq: 0
    property string cpuLoad: ""
    property int cpuThreads: 0

    // A rate, so one reading says nothing: these hold the previous sample of
    // the cumulative jiffy counters and the percentage is the difference.
    property real lastCpuTotal: 0
    property real lastCpuIdle: 0

    // ---------------- Memory ----------------
    property real ramUsed: 0
    property real ramTotal: 0
    property real ramPercent: 0
    property real swapUsed: 0
    property real swapTotal: 0

    // ---------------- GPU ----------------
    property string gpuName: ""
    property real gpuPercent: 0
    property real gpuVramUsed: 0
    property real gpuVramTotal: 0
    property real gpuTemp: 0
    property real gpuPower: 0
    property bool gpuAvailable: false

    // The hwmon path for the CPU package sensor, resolved at startup.
    property string cpuTempPath: ""

    // Read the moment the path is known. The watch timer below fires on start
    // too, but that first tick happens BEFORE the discovery process has
    // answered, so it returns empty-handed and the thermal alert then sits
    // blind until the next tick. Caught while testing: with the threshold
    // lowered to force an alert, the island stayed on media for the first few
    // seconds and only woke up on the second tick.
    onCpuTempPathChanged: root.readCpuTemp()

    function readCpuTemp(): void {
        if (!root.cpuTempPath)
            return;
        tempFile.reload();
        const temp = tempFile.text();
        if (temp)
            root.cpuTemp = Number(temp.trim()) / 1000;
    }

    function gib(kb: real): real {
        return kb / 1024 / 1024;
    }

    // ---------------- Thermal alert ----------------
    //
    // THE NUMBERS ARE THE HARDWARE'S, NOT MINE.
    //
    // CPU. coretemp publishes its own limits: temp1_max is 80 C and
    // temp1_crit is 100 C, which is TJmax -- the point where Raptor Lake
    // starts throttling to protect itself. 80 is not an alarm: a 13600K under
    // a sustained load sits in the eighties and that is what a cooler is for.
    // 90 is: it is past anything a healthy load explains and leaves 10 C of
    // margin before the chip starts slowing itself down.
    //
    // GPU. Blackwell no longer reports an absolute limit; it reports HEADROOM.
    // Measured on this card: temperature.gpu 44 C with T.Limit 41, and the
    // slowdown spec at -2 -- so throttling begins at about 85 C. 83 puts the
    // warning just before the card starts losing performance rather than
    // after.
    //
    // Both are the point where something is WRONG, not the point where
    // something is warm. An indicator that cries during a game is one that
    // gets ignored during a failure.
    readonly property int cpuHotAt: 90
    readonly property int gpuHotAt: 83

    // Cleared lower than it is set. Without this gap the alert would flicker
    // on and off every sample while the temperature hovered on the threshold,
    // which is exactly the moment it is being read.
    readonly property int cpuCoolAt: 85
    readonly property int gpuCoolAt: 78

    property bool cpuHot: false
    property bool gpuHot: false

    onCpuTempChanged: root.cpuHot = root.cpuHot
        ? root.cpuTemp > root.cpuCoolAt
        : root.cpuTemp >= root.cpuHotAt

    onGpuTempChanged: root.gpuHot = root.gpuHot
        ? root.gpuTemp > root.gpuCoolAt
        : root.gpuTemp >= root.gpuHotAt

    // Memory, on the same principle as the temperatures: the point where
    // something is WRONG, not where something is busy. Past 90% the kernel is
    // out of room to cache with and starts reclaiming to serve allocations --
    // the machine has not failed yet, but it is about to get slow in a way
    // that looks like a hardware problem if you do not know why.
    readonly property int ramHotAt: 90
    readonly property int ramCoolAt: 85

    property bool ramHot: false

    onRamPercentChanged: root.ramHot = root.ramHot
        ? root.ramPercent > root.ramCoolAt
        : root.ramPercent >= root.ramHotAt

    readonly property bool thermalAlert: root.cpuHot || root.gpuHot

    // What the island shows when more than one thing is wrong at once.
    // Heat wins: a hot chip throttles or shuts down to protect itself, while
    // full memory makes the machine slow. Both are worth interrupting for;
    // only one of them ends the session on its own.
    readonly property bool alert: root.thermalAlert || root.ramHot
    readonly property string alertKind: root.thermalAlert ? "thermal" : "memory"

    // Whichever is further past its own threshold, so the island names the
    // part that is actually in trouble when both are.
    readonly property string thermalSource: {
        if (root.cpuHot && root.gpuHot)
            return (root.cpuTemp - root.cpuHotAt) >= (root.gpuTemp - root.gpuHotAt) ? "CPU" : "GPU";
        return root.cpuHot ? "CPU" : "GPU";
    }

    readonly property real thermalTemp: root.thermalSource === "CPU" ? root.cpuTemp : root.gpuTemp

    // ---------------- Readers ----------------
    FileView {
        id: statFile

        path: "/proc/stat"
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
    }

    FileView {
        id: loadFile

        path: "/proc/loadavg"
    }

    FileView {
        id: cpuInfoFile

        path: "/proc/cpuinfo"
    }

    FileView {
        id: tempFile

        path: root.cpuTempPath
    }

    // WHY THE SENSOR PATH IS DISCOVERED AND NOT WRITTEN DOWN.
    //
    // The package sensor is currently /sys/class/hwmon/hwmon7/temp1_input, and
    // that number is assigned in probe order: add a drive, load a module in a
    // different order, boot a different kernel, and hwmon7 is something else
    // entirely -- the same trap that made hyprland.lua match monitors by
    // description instead of by connector name.
    //
    // So it is looked up by what it IS: the hwmon whose `name` is coretemp,
    // and inside it the sensor labelled "Package id 0" -- the whole-package
    // reading rather than one core, which is the one number worth showing.
    //
    // Once, at startup, not on the sample timer.
    Process {
        running: true
        // grep + sed rather than a shell loop, and NOT a template literal.
        // The loop version needed ${l%_label} inside QML backticks, where the
        // dollar has its own meaning -- the command reached sh with the
        // substitution already mangled and the path came back empty, which is
        // why the temperature read 0. A plain string has no interpolation to
        // fight over.
        //
        // "Package id 0" is unique to coretemp, so matching the label is
        // enough to identify both the driver and the sensor.
        command: ["sh", "-c", "grep -l 'Package id 0' /sys/class/hwmon/hwmon*/temp*_label 2>/dev/null | head -1 | sed 's/_label$/_input/'"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line)
                    root.cpuTempPath = line.trim();
            }
        }
    }

    // nvidia-smi held OPEN in a loop rather than spawned every two seconds.
    // Starting it costs about 20 ms of process setup; `-l` makes one process
    // emit one line per interval instead, which is the same shape the cava
    // spectrum uses.
    // ALWAYS running, not just while the Performance tab is open: the island
    // has to be able to warn about a hot card whether or not anyone is looking
    // at the dashboard. The interval is what changes -- 2 s while the tab is
    // being read, 5 s the rest of the time, which is plenty for a temperature
    // that takes tens of seconds to move.
    Process {
        running: true

        command: ["nvidia-smi",
            "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
            "--format=csv,noheader,nounits",
            "-l", root.active ? "2" : "5"]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                const f = line.split(",").map(v => v.trim());
                if (f.length < 6)
                    return;
                root.gpuName = f[0];
                root.gpuPercent = Number(f[1]) || 0;
                // nvidia-smi reports MiB.
                root.gpuVramUsed = (Number(f[2]) || 0) / 1024;
                root.gpuVramTotal = (Number(f[3]) || 0) / 1024;
                root.gpuTemp = Number(f[4]) || 0;
                root.gpuPower = Number(f[5]) || 0;
                root.gpuAvailable = true;
            }
        }
    }

    // Split out of sample() so the always-on watch below can call it too.
    // Memory is the second thing the island can raise an alarm about, and an
    // alarm that only works while the dashboard happens to be open is not an
    // alarm.
    function readMemory(): void {
        memFile.reload();
        const mem = memFile.text();
        if (!mem)
            return;
        {
            const total = parseFloat(mem.match(/MemTotal:\s+(\d+)/)?.[1] ?? 0);
            // MemAvailable and not MemFree: free counts the page cache as used
            // and reports a warm machine as nearly full.
            const available = parseFloat(mem.match(/MemAvailable:\s+(\d+)/)?.[1] ?? 0);
            const swapTotal = parseFloat(mem.match(/SwapTotal:\s+(\d+)/)?.[1] ?? 0);
            const swapFree = parseFloat(mem.match(/SwapFree:\s+(\d+)/)?.[1] ?? 0);
            if (total > 0) {
                root.ramTotal = root.gib(total);
                root.ramUsed = root.gib(total - available);
                root.ramPercent = (1 - available / total) * 100;
            }
            root.swapTotal = root.gib(swapTotal);
            root.swapUsed = root.gib(swapTotal - swapFree);
        }
    }

    function sample(): void {
        statFile.reload();
        loadFile.reload();
        cpuInfoFile.reload();
        if (root.cpuTempPath)
            tempFile.reload();

        // ---- CPU load ----
        const stat = statFile.text();
        if (stat) {
            const fields = stat.split("\n")[0].trim().split(/\s+/).slice(1).map(parseFloat);
            const total = fields.reduce((a, b) => a + b, 0);
            // Fields 3 and 4 are idle and iowait: both are the CPU not working.
            const idle = fields[3] + fields[4];
            const deltaTotal = total - root.lastCpuTotal;
            const deltaIdle = idle - root.lastCpuIdle;
            if (root.lastCpuTotal > 0 && deltaTotal > 0)
                root.cpuPercent = (1 - deltaIdle / deltaTotal) * 100;
            root.lastCpuTotal = total;
            root.lastCpuIdle = idle;
        }

        root.readMemory();

        // ---- Load average ----
        const load = loadFile.text();
        if (load)
            root.cpuLoad = load.trim().split(/\s+/).slice(0, 3).join("  ");

        // ---- Model and frequency ----
        const info = cpuInfoFile.text();
        if (info) {
            if (!root.cpuModel)
                root.cpuModel = (info.match(/model name\s*:\s*(.+)/)?.[1] ?? "").trim();
            // Line scan and NOT String.matchAll: Qt's JS engine does not
            // implement it, so the call threw, the whole block after it was
            // skipped, and clock and thread count stayed at zero while the
            // model name -- read by a plain match() above -- came through
            // fine. That split is what gave the bug away.
            const freqs = info.split("\n")
                .filter(l => l.startsWith("cpu MHz"))
                .map(l => Number(l.split(":")[1]))
                .filter(v => !isNaN(v));
            if (freqs.length > 0) {
                root.cpuThreads = freqs.length;
                // The average across threads. A single core's number jumps
                // between its boost and its idle clock several times a second
                // and reads as noise.
                root.cpuFreq = freqs.reduce((a, b) => a + b, 0) / freqs.length;
            }
        }

        // ---- Temperature ----
        const temp = tempFile.text();
        if (temp)
            root.cpuTemp = Number(temp.trim()) / 1000;
    }

    Timer {
        interval: root.sampleInterval
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // The alert watch. Runs whether or not anyone has the dashboard open,
    // because the whole point of the island's alert is to reach someone who
    // was not looking. Only the two things that can raise one are read here --
    // temperature and memory. The rest of the parsing stays gated on `active`.
    Timer {
        // 2 s and not 5. FileView.reload() is asynchronous: text() in the same
        // tick still returns the previous contents, so the first reading of a
        // fresh process is always empty and the alert only arms one tick
        // later. Seen twice while testing -- with a threshold lowered to force
        // an alert, the island stayed on media for the first few seconds both
        // times. The interval IS the arming delay, and reading two small files
        // costs little enough that it may as well be short.
        interval: 2000
        repeat: true
        running: !root.active
        triggeredOnStart: true

        onTriggered: {
            root.readCpuTemp();
            root.readMemory();
        }
    }
}
