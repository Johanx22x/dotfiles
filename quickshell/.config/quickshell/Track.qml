// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - presenting track metadata
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// What MPRIS hands over is not always what should be on screen. This is the
// one place that decides the difference, because the same track is shown in
// three: the bar's media widget, the island and the dashboard. Three copies
// of the same tidy-up is three chances for them to drift apart.

pragma Singleton

import Quickshell

Singleton {
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
}
