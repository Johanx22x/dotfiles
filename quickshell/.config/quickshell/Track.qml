// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - presenting track metadata
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// What MPRIS hands over is not always what should be on screen. This is the
// one place that decides the difference, because the same track is shown in
// three: the bar's media widget, the island and the dashboard. Three copies
// of the same tidy-up is three chances for them to drift apart.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // Artist as it should be READ.
    //
    // YouTube generates a channel per artist for its music catalogue and
    // names it "<Artist> - Topic". Those channels are what a browser playing
    // YouTube Music reports over MPRIS, so half the tracks arrive with a
    // suffix that means "this is an auto-generated channel" -- an artefact of
    // where the audio came from, not part of anyone's name.
    //
    // Anchored to the END of the string: a band actually called something
    // ending in "Topic" keeps its name, and only the trailing marker goes.
    function artist(raw: string): string {
        if (!raw)
            return "";
        return raw.replace(/\s*-\s*Topic$/, "");
    }

    // ---- WHICH PLAYER IS "THE" PLAYER ----
    //
    // Decided here because it was decided in three places -- the island, the
    // dashboard and the dashboard's own position poll -- with the same line
    // copied into each: `players.find(p => p.isPlaying) ?? players[0]`. That
    // line has no opinion about proxies, and there is one on this bus.
    //
    // playerctld IS A MIRROR, NOT A PLAYER. It is the daemon behind the
    // `playerctl` the media keys call (see hyprland.lua and config.kdl), it
    // is D-Bus activated, and it republishes whatever the last active player
    // said under a bus name of its own. Measured on the running session with
    // one browser playing:
    //
    //   org.mpris.MediaPlayer2.firefox.instance_1_45   Identity "Mozilla zen"
    //   org.mpris.MediaPlayer2.playerctld              Identity "Mozilla zen"
    //
    // -- same identity, same mpris:trackid, same metadata. Quickshell's
    // MprisWatcher registers every name starting with org.mpris.MediaPlayer2
    // and filters none of them (src/services/mpris/watcher.cpp), so
    // `Mpris.players.values` holds the SAME player twice and `find` picks
    // whichever comes first.
    //
    // WHY THAT IS NOT MERELY UNTIDY. Quickshell does not read Position off
    // the bus when asked for it; `MprisPlayer::position()` returns the last
    // value the player sent plus the wall-clock time since it arrived
    // (src/services/mpris/player.cpp). The mirror and the original are two
    // objects with two independent anchors, refreshed at two different
    // moments, so the elapsed time you get depends on which of the two the
    // `find` happened to land on -- and it can land differently between one
    // evaluation and the next.
    //
    // MATCHED ON THE BUS NAME AND NOT ON THE IDENTITY, because the identity
    // is the thing it copies.
    readonly property string proxyBus: "org.mpris.MediaPlayer2.playerctld"

    // The mirror is dropped only while there is something to mirror. With
    // nothing else on the bus it is the only account of what was playing, and
    // a shell that showed nothing there would be hiding a player that exists.
    readonly property var players: {
        const all = Mpris.players.values;
        const real = all.filter(p => (p.dbusName ?? "") !== root.proxyBus);
        return real.length > 0 ? real : all;
    }

    // Prefer what is actually playing; fall back to the first player that
    // exists, so a paused track still holds the island and fills the panel.
    readonly property var active: {
        const list = root.players;
        if (list.length === 0)
            return null;
        return list.find(p => p.isPlaying) ?? list[0];
    }

    // ---- The cover art, remembered for longer than anyone is looking ----
    //
    // ZEN RETRACTS THE ARTWORK AND LEAVES IT RETRACTED. It publishes
    // mpris:artUrl and then republishes Metadata for the same track with the
    // key absent, repeatedly, within milliseconds. MPRIS Metadata is one
    // whole map, so a sender that rebuilds it without the artwork key has
    // retracted the artwork, and `MprisPlayer.trackArtUrl` goes empty.
    //
    // The retracted state is not a blip, it is where the track SETTLES.
    // Measured on the running session with the player paused on a real track:
    //
    //   busctl --user get-property ... Metadata
    //     mpris:trackid, xesam:title, xesam:album, xesam:artist,
    //     xesam:url, mpris:length          -- and NO mpris:artUrl
    //   ls ~/.zen/firefox-mpris/
    //     3304_266.png                     -- the cover, still on disk
    //
    // So the picture exists and the player has stopped admitting to it.
    //
    // WHY THIS LIVES IN A SINGLETON AND NOT IN THE CARD. The first attempt at
    // this held the cover in the dashboard's media card, which works only for
    // as long as that card exists -- and the popout is built behind
    // `Loader { active: root.isOpen }`, so it is DESTROYED every time the
    // panel closes. Reopening it on a settled track therefore started from
    // nothing, found trackArtUrl empty because it always is by then, and drew
    // the stand-in. The cover was not lost by the retraction; it was lost by
    // the close. Anything that has to outlive the panel cannot be stored in
    // it. Same trap as NightLight in shell.qml, which is armed there for
    // exactly this reason -- and so is this, so that a cover published before
    // the first open is still seen.
    property bool armed: true

    // dbusName -> the last art URL that player admitted to.
    //
    // Only ever set to a NON-EMPTY url, and only ever removed by a genuine
    // track change. An update that carries no artwork cannot take the
    // artwork away, which is the whole point.
    property var covers: ({})

    // dbusName -> the identity of the track currently held, merged across
    // updates. See noteTrack for why it is merged rather than replaced.
    property var identities: ({})

    // A cover offered. Empty is not an offer, it is silence.
    function noteArt(bus: string, url: string) {
        if (!bus || !url || root.covers[bus] === url)
            return;
        const next = Object.assign({}, root.covers);
        next[bus] = url;
        root.covers = next;
    }

    // WHAT IS ALLOWED TO THROW THE COVER AWAY: the track actually changing,
    // and nothing else. Holding a cover across a track change would be worse
    // than holding none, because it would confidently show the wrong album.
    //
    // This cannot key on mpris:trackid: Zen publishes one constant object
    // path -- /org/mpris/MediaPlayer2/firefox -- for every track it plays.
    // So the identity is built out of what the track IS.
    //
    // AND IT COMPARES ONLY THE FIELDS BOTH SIDES ACTUALLY CARRY. A field the
    // update did not carry is unknown, not changed, so it is skipped here and
    // kept below.
    //
    // THIS IS NOT DEFENSIVE PROGRAMMING -- IT IS THE BUG. Watching the real
    // bus while Zen played three tracks, xesam:album arrives EMPTY on a track
    // change and is filled in about two seconds later, in the same
    // republication that retracts mpris:artUrl:
    //
    //   998462.3  title="Hello"  album=""       art absent   <- new track
    //   998849.3  title="Hello"  album=""       art _267.png <- cover
    //   1000609.5 title="Hello"  album="Hello"  art absent   <- album fills in
    //   1000634.5 title="Hello"  album="Hello"  art _268.png
    //
    // A key built by joining title, album and artist changes at 1000609.5
    // even though the track did not, and the previous version of this cleared
    // the cover there -- the guard firing on the very event it was written to
    // survive. Replayed over that capture, the joined key fired four times
    // across two tracks and two of the four were spurious; the comparison
    // below fires exactly twice, on the two real changes.
    function noteTrack(bus: string, title: string, album: string, performer: string) {
        if (!bus)
            return;

        const held = root.identities[bus] ?? {
            title: "",
            album: "",
            artist: ""
        };
        const incoming = {
            title: title ?? "",
            album: album ?? "",
            artist: performer ?? ""
        };

        let different = false;
        for (const field of ["title", "album", "artist"]) {
            if (held[field] && incoming[field] && held[field] !== incoming[field]) {
                different = true;
                break;
            }
        }

        // On a real change the new identity replaces the old outright. On a
        // partial republication the fields it omitted keep the values they
        // had, so the next update still has something to compare against
        // instead of silently starting over.
        const merged = different ? incoming : {
            title: incoming.title || held.title,
            album: incoming.album || held.album,
            artist: incoming.artist || held.artist
        };

        const nextIdentities = Object.assign({}, root.identities);
        nextIdentities[bus] = merged;
        root.identities = nextIdentities;

        if (different && root.covers[bus] !== undefined) {
            const nextCovers = Object.assign({}, root.covers);
            delete nextCovers[bus];
            root.covers = nextCovers;
        }
    }

    // A PLAYER THAT HAS LEFT THE BUS KEEPS NOTHING HERE. Browser MPRIS bus
    // names carry an instance number -- org.mpris.MediaPlayer2.firefox.\
    // instance_1_45 -- so without this, every browser restart would add a
    // permanent entry to a singleton that lives from login. The second reason
    // matters more: a player with a STABLE bus name, like spotify or mpv,
    // would otherwise inherit its own previous session's identity and cover,
    // and that cover points at a file which may be long gone.
    function forget(bus: string) {
        if (!bus)
            return;
        if (root.covers[bus] !== undefined) {
            const nextCovers = Object.assign({}, root.covers);
            delete nextCovers[bus];
            root.covers = nextCovers;
        }
        if (root.identities[bus] !== undefined) {
            const nextIdentities = Object.assign({}, root.identities);
            delete nextIdentities[bus];
            root.identities = nextIdentities;
        }
    }

    // One watcher per player, for as long as the player is on the bus. This
    // is what makes the memory independent of anything being on screen.
    Instantiator {
        model: Mpris.players

        delegate: QtObject {
            id: watcher

            required property MprisPlayer modelData

            readonly property string bus: watcher.modelData?.dbusName ?? ""
            readonly property string art: watcher.modelData?.trackArtUrl ?? ""
            readonly property string title: watcher.modelData?.trackTitle ?? ""
            readonly property string album: watcher.modelData?.trackAlbum ?? ""
            readonly property string performer: watcher.modelData?.trackArtist ?? ""

            // CAPTURED, NOT READ AT DESTRUCTION. By the time the delegate is
            // torn down modelData may already be gone, and the binding below
            // would hand forget() an empty string.
            property string ownBus: ""

            function sync() {
                // The track first: a genuine change clears the old cover, and
                // the new one is then free to arrive in either order.
                root.noteTrack(watcher.bus, watcher.title, watcher.album, watcher.performer);

                // THE LIVE VALUE AND NOT `watcher.art`. trackTitle and
                // trackArtUrl are four independent bindable properties with
                // four independent notify signals, so nothing says
                // trackArtUrlChanged has been delivered by the time
                // onTitleChanged runs. Reading the cached binding here would,
                // on a genuine track change, re-insert the PREVIOUS track's
                // cover immediately after noteTrack had just dropped it --
                // and Zen opens every track with the artwork retracted, so
                // that wrong cover would then sit there until the real one
                // arrived. Reading through modelData cannot be stale.
                root.noteArt(watcher.bus, watcher.modelData?.trackArtUrl ?? "");
            }

            onArtChanged: root.noteArt(watcher.bus, watcher.art)
            onTitleChanged: watcher.sync()
            onAlbumChanged: watcher.sync()
            onPerformerChanged: watcher.sync()

            Component.onCompleted: {
                watcher.ownBus = watcher.bus;
                watcher.sync();
            }

            Component.onDestruction: root.forget(watcher.ownBus)
        }
    }
}
