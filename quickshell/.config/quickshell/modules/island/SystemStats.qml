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
//   GPU                           whichever card this machine has, and WHICH
//                                 ONE is discovered too. NVIDIA exposes
//                                 nothing useful in sysfs, so utilisation,
//                                 VRAM, temperature and power all come out of
//                                 nvidia-smi -- the one reading here that
//                                 costs a process. amdgpu publishes all four
//                                 as plain sysfs files, so on a Radeon there
//                                 is no process to hold open at all and the
//                                 GPU is read exactly like the CPU is.
//
// WHY THE VENDOR IS DETECTED AND NOT CONFIGURED.
//
// These dotfiles are stowed onto more than one machine and this file is the
// same file on all of them: one has a GeForce, another a Radeon. A setting
// would make the shell wrong on every machine until somebody remembered to
// change it, and wrong in the worst way -- a GPU card sitting at zero with
// nothing on screen to say why, which reads as a broken panel rather than a
// missed checkbox. The kernel already knows which driver is bound to which
// card. Asking it costs one shell at startup and cannot disagree with the
// hardware it is running on.
//
// The same reasoning rules out hardcoding a card number or a model name: both
// were true on exactly one machine on exactly one boot.
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

    // "" until the detection below answers, then "nvidia" or "amd". It stays
    // "" on a machine with neither, and that is what keeps the panel quiet
    // there: nvidia-smi is never spawned, no timer runs, and every figure
    // above stays at its initial zero rather than half of them being real.
    property string gpuVendor: ""

    // The amdgpu sysfs files, resolved at startup for the same reason
    // cpuTempPath is. An empty one means this particular card does not publish
    // that reading -- an APU with no power telemetry, say -- and the figure it
    // feeds keeps its zero instead of the panel inventing one.
    property string gpuBusyPath: ""
    property string gpuVramPath: ""
    property string gpuTempPath: ""
    property string gpuPowerPath: ""

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
    // The threshold is one number for both vendors, which only holds because
    // both are fed the same KIND of reading: nvidia-smi's temperature.gpu and
    // amdgpu's temp1 are the edge sensor on their respective cards. amdgpu's
    // temp2 is the junction hotspot, a number tens of degrees higher by
    // design, and pointing this at it would have the island shouting through
    // every game. That is the whole reason the detection asks for temp1 by
    // name instead of taking whichever sensor comes first.
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

    // The amdgpu readings. Four files instead of one process, and each one
    // holds a single number the driver keeps current -- the same deal /proc
    // offers for the CPU, which is why the GPU costs a process on one machine
    // and nothing on the other. radeontop and the like would only be another
    // program reading these for us, and would have to be installed first.
    FileView {
        id: gpuBusyFile

        path: root.gpuBusyPath
    }

    FileView {
        id: gpuVramFile

        path: root.gpuVramPath
    }

    FileView {
        id: gpuTempFile

        path: root.gpuTempPath
    }

    FileView {
        id: gpuPowerFile

        path: root.gpuPowerPath
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

    // WHICH GPU THIS MACHINE HAS, asked once at startup.
    //
    // It walks /sys/class/drm and reads the PCI driver bound to each card,
    // which is the one question that answers everything at once: it names the
    // vendor, it proves the card is PRESENT and BOUND rather than merely
    // having its userspace tools installed, and it hands over the sysfs
    // directory the amdgpu readings live in. `command -v nvidia-smi` would
    // have answered a different and weaker question -- a machine can carry the
    // tool with the card pulled out.
    //
    // NVIDIA is looked for first and wins outright. Two cards from different
    // vendors in one machine is a tie somebody has to break, and nvidia-smi is
    // the richer of the two sources, so it gets the vote. On NVIDIA the driver
    // link is the PCI driver `nvidia`, and /sys/class/drm/cardN only exists at
    // all once nvidia_drm has registered the card -- which it always has here,
    // since there is no Wayland compositor to run this shell under otherwise.
    //
    // AMONG SEVERAL amdgpu CARDS, the one with the most VRAM wins. Card
    // numbers are probe order, and on a machine with an APU and a discrete
    // Radeon the APU usually enumerates first -- taking the first match would
    // reliably pick the wrong card and report the chip nobody is gaming on.
    // Memory size is the one property that actually separates them.
    //
    // NOT a template literal, for the reason recorded on the CPU sensor
    // lookup above: `${...}` and `$(...)` both mean something to QML's string
    // interpolation and the command would reach sh already mangled. Plain
    // strings joined with + have nothing to interpolate. The backslashes in
    // the sed are DOUBLED because QML eats a single one before sh ever sees
    // it.
    //
    // Output is one key=value per line, and a key is simply absent when the
    // machine cannot answer it. No GPU means no output at all.
    Process {
        running: true

        command: ["sh", "-c",
            "amd=\n" +
            "amdv=-1\n" +
            "for c in /sys/class/drm/card*; do\n" +
            // Skips the connector directories -- card1-DP-1 and friends --
            // whose `device` points back at the card and has no driver link.
            "[ -e $c/device/driver ] || continue\n" +
            "case $(readlink -f $c/device/driver) in\n" +
            "*/nvidia) echo vendor=nvidia; exit 0 ;;\n" +
            "*/amdgpu)\n" +
            "d=$(readlink -f $c/device)\n" +
            "v=0\n" +
            "[ -r $d/mem_info_vram_total ] && read v < $d/mem_info_vram_total\n" +
            // Anything that is not a plain number counts as no VRAM rather
            // than reaching `[ -gt ]` and printing a shell error at us.
            "case $v in ''|*[!0-9]*) v=0 ;; esac\n" +
            // amdv starts at -1 so the first amdgpu card always wins the
            // comparison, even one reporting zero bytes, and only a strictly
            // larger card displaces it afterwards.
            "[ $v -gt $amdv ] && { amd=$d; amdv=$v; }\n" +
            ";;\n" +
            "esac\n" +
            "done\n" +
            "case x$amd in x) exit 0 ;; esac\n" +
            "echo vendor=amd\n" +
            // Total VRAM is a constant, so it is emitted as the value itself
            // rather than as one more file to re-read every two seconds.
            "[ $amdv -gt 0 ] && echo vramtotal=$amdv\n" +
            "[ -r $amd/gpu_busy_percent ] && echo busy=$amd/gpu_busy_percent\n" +
            "[ -r $amd/mem_info_vram_used ] && echo vramused=$amd/mem_info_vram_used\n" +
            // The hwmon number is probe order too, so it is found by looking
            // rather than by assuming hwmon0. Both nestings are globbed: the
            // hwmon class puts its device under <parent>/hwmon/hwmonN for a
            // bus device like this PCI one, but not every driver in the tree
            // ends up that way and the extra pattern costs nothing.
            "for h in $amd/hwmon/hwmon* $amd/hwmon*; do\n" +
            "[ -f $h/name ] || continue\n" +
            // temp1 and NOT temp2. temp1 is the edge sensor, the counterpart
            // of nvidia-smi's temperature.gpu; temp2 is the junction hotspot,
            // which runs far above it and would trip gpuHotAt below during
            // perfectly ordinary load. Same reading on both machines or the
            // threshold means two different things.
            "[ -r $h/temp1_input ] && echo temp=$h/temp1_input\n" +
            // power1_average preferred, power1_input as the fallback: some
            // SMU generations publish only one of the two.
            "[ -r $h/power1_average ] && echo power=$h/power1_average\n" +
            "[ -r $h/power1_average ] || { [ -r $h/power1_input ] && echo power=$h/power1_input; }\n" +
            "break\n" +
            "done\n" +
            // THE NAME IS LOOKED UP, NOT WRITTEN DOWN. amdgpu's own
            // product_name attribute is documented as server cards only, so
            // on a desktop Radeon the only name the system holds is the one
            // pci.ids gives for the card's PCI ID, which is what lspci
            // prints. The sed drops the slot and class, drops the revision,
            // drops the AMD/ATI vendor tag, and then takes the bracketed
            // marketing name if there is one -- "Navi 24 [Radeon RX
            // 6400/6500 XT/6500M]" becomes "Radeon RX 6400/6500 XT/6500M",
            // which is the same shape the dashboard shows for NVIDIA once it
            // has trimmed the vendor off. A card pci.ids does not know falls
            // back to whatever it does know, and no lspci at all prints
            // nothing, leaving gpuName empty rather than wrong.
            "lspci -s $(basename $amd) 2>/dev/null | sed -n" +
            " -e 's/^[^ ]* [^:]*: //'" +
            " -e 's/ (rev [^)]*)$//'" +
            " -e 's|^Advanced Micro Devices, Inc. \\[AMD/ATI\\] ||'" +
            " -e 's/.*\\[\\(.*\\)\\].*/\\1/'" +
            " -e 's/^./name=&/p'\n"]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                const split = line.indexOf("=");
                if (split < 0)
                    return;
                const value = line.slice(split + 1).trim();
                switch (line.slice(0, split)) {
                case "vendor":
                    root.gpuVendor = value;
                    break;
                case "vramtotal":
                    // amdgpu reports bytes, nvidia-smi MiB. Both end in GiB.
                    root.gpuVramTotal = Number(value) / 1024 / 1024 / 1024;
                    break;
                case "busy":
                    root.gpuBusyPath = value;
                    break;
                case "vramused":
                    root.gpuVramPath = value;
                    break;
                case "temp":
                    root.gpuTempPath = value;
                    break;
                case "power":
                    root.gpuPowerPath = value;
                    break;
                case "name":
                    root.gpuName = value;
                    break;
                }
            }
        }
    }

    // nvidia-smi held OPEN in a loop rather than spawned every two seconds.
    // Starting it costs about 20 ms of process setup; `-l` makes one process
    // emit one line per interval instead, which is the same shape the cava
    // spectrum uses.
    // ALWAYS running once the card is known, not just while the Performance
    // tab is open: the island has to be able to warn about a hot card whether
    // or not anyone is looking at the dashboard. The interval is what changes
    // -- 2 s while the tab is being read, 5 s the rest of the time, which is
    // plenty for a temperature that takes tens of seconds to move.
    //
    // Gated on the detection rather than started unconditionally, so that on
    // a machine without the card this is a process that is never spawned
    // instead of one that fails on every launch and writes about it.
    Process {
        running: root.gpuVendor === "nvidia"

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
                // The vendor prefix goes here and not at the point of display,
                // for the same reason the AMD branch trims its own: a card is
                // named once, where the vendor is known. This used to be a
                // .replace() in Dashboard.qml, which meant one vendor was
                // normalised upstream and the other downstream, and only the
                // NVIDIA half was ever applied.
                root.gpuName = f[0].replace(/^NVIDIA /, "");
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

    // One sysfs number, or null when there is nothing to say yet -- the file
    // was not found at detection, or the reload has not landed. null and not
    // 0, because 0 is a legitimate reading for three of the four figures and
    // the caller has to be able to tell "idle" from "no answer".
    //
    // Reads BEFORE the reload lands, deliberately: FileView.reload() is
    // asynchronous, so text() in the same tick still returns the previous
    // contents. Every reading here is therefore one tick old, which for a
    // GPU sampled every 2 s is the difference between a temperature and the
    // same temperature. readCpuTemp() above works the same way.
    function sysfsNumber(view: var, path: string): var {
        if (!path)
            return null;
        view.reload();
        const text = view.text();
        if (!text)
            return null;
        const value = Number(text.trim());
        return isNaN(value) ? null : value;
    }

    // The amdgpu counterpart of the nvidia-smi block above: same four figures,
    // same units out, no process. Each is assigned only if the card answered,
    // so a card that publishes no power leaves gpuPower at zero rather than
    // flickering between a real number and a fabricated one.
    function readGpu(): void {
        const busy = root.sysfsNumber(gpuBusyFile, root.gpuBusyPath);
        const vram = root.sysfsNumber(gpuVramFile, root.gpuVramPath);
        const temp = root.sysfsNumber(gpuTempFile, root.gpuTempPath);
        const power = root.sysfsNumber(gpuPowerFile, root.gpuPowerPath);

        if (busy !== null)
            root.gpuPercent = busy;
        // Bytes.
        if (vram !== null)
            root.gpuVramUsed = vram / 1024 / 1024 / 1024;
        // Millidegrees, like the CPU package sensor.
        if (temp !== null)
            root.gpuTemp = temp / 1000;
        // Microwatts.
        if (power !== null)
            root.gpuPower = power / 1000000;

        if (busy !== null || temp !== null)
            root.gpuAvailable = true;
    }

    // Always running, on the same 2 s / 5 s split as the nvidia-smi loop and
    // for the same reason: the island's heat warning has to work while the
    // dashboard is shut. Only started once detection has said "amd", so on
    // every other machine this timer never ticks.
    Timer {
        interval: root.active ? 2000 : 5000
        repeat: true
        running: root.gpuVendor === "amd"
        triggeredOnStart: true
        onTriggered: root.readGpu()
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
