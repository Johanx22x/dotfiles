// Zen preferences that have to hold for the theming to work at all.
//
// user.js is re-applied on EVERY start, so these are not defaults: they are
// pinned. Anything changed from the UI that also lives here goes back on the
// next launch. Keep this file to the minimum that the rice depends on;
// everything else belongs in the UI, where prefs.js records it.
//
// The profile is ~/.zen/rice, a fixed name instead of the random
// xxxxxxxx.Default that Zen creates on its own. Without a stable path,
// matugen has nowhere to write and stow has nothing to link. It is declared
// in ~/.zen/profiles.ini (Default=1) and Zen bound its install hash to it in
// ~/.zen/installs.ini on the first run.

// Without this, userChrome.css and userContent.css are not read at all --
// the chrome/ directory is ignored outright. This is THE pref of the whole
// setup.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Glass. Zen can hand the compositor a real ARGB window and paint its own
// chrome translucent, which is what lets Hyprland's blur (size 8, passes 2)
// show through the sidebar and the toolbar.
//
// This is deliberately NOT a Hyprland `opacity` windowrule. As hyprland.lua
// warns at the rule for Nautilus, opacity applies to the WHOLE window --
// text and icons fade with it. Zen's transparency only affects the chrome
// background, so the text stays fully opaque over the blur. Same look,
// readable.
//
// The pref works by flipping --zen-themed-toolbar-bg-transparent to
// `transparent` inside a media query; userChrome.css then tints it back to a
// translucent Tokyo Night. Turning this off means the tint there has to go
// back to a solid colour, or the chrome ends up semi-transparent over an
// opaque window.
user_pref("zen.widget.linux.transparency", true);

// ...and the pref that undoes it the moment the window loses focus. Zen
// ships this ON: zen-browser-ui.css carries
//
//   @media (-moz-pref("zen.view.grey-out-inactive-windows")) {
//     &:-moz-window-inactive { background: InactiveCaption; }
//
// on #zen-main-app-wrapper. InactiveCaption is an OPAQUE system colour, so
// clicking on any other window turned the glass into a flat grey panel. It
// is a reasonable default for a normal desktop and wrong for this one: with
// focus-follows-mouse the browser is "inactive" every time the pointer
// leaves it, and the same reasoning already applies to GTK3 in
// gtk3-colors.css -- a window that changes colour when you look away reads
// as broken, not as unfocused.
user_pref("zen.view.grey-out-inactive-windows", false);

// Style Editor over the browser's own interface (Ctrl+Shift+Alt+I ->
// Style Editor -> userChrome). Not needed for the theme to work, only to
// work ON it: edits made there apply live, which is the only way to try a
// rule without restarting.
user_pref("devtools.chrome.enabled", true);
user_pref("devtools.debugger.remote-enabled", true);
