# Spike: antialiased blurred glass under niri

Throwaway probes and measurements. Nothing here is meant to ship; the branch
exists so the numbers behind the recommendation can be re-run.

Each probe is a standalone Quickshell config with its own entry point, run
alongside (never instead of) the real shell:

    qs -p spike/probes/<name>

Every probe uses a `blur-spike-*` layer-shell namespace, takes no input
(`mask: Region {}`) and is killed by a recorded PID.

## probes/xray

Two identical translucent patches over the same backdrop; the upper one asks
for blur through `ext-background-effect`, the lower one asks for nothing.
Answers what niri actually blurs.

## probes/kernel

A surface that paints nothing and asks for blur behind one rectangle, so grim
captures niri's blurred backdrop with no glass tint in front of it. Used to fit
a client-side blur to niri's dual Kawase.

## probes/screencopy

Route A, as far as it goes: `ScreencopyView` on the whole output, offset so the
pixels behind the panel land behind the panel, blurred with `MultiEffect` and
masked with the panel's own shape. The same capture is also drawn raw at
quarter scale, which is where the answer is -- the copy contains the probe's
own strip and, inside it, a copy of the quarter scale view, and inside that
another one. No screenshot of this is committed because the capture is of the
whole desktop; run the probe and look at the box in the lower left.

## probes/bar

Three versions of the same full width strip, for cost: `bar-none.qml` paints
it and nothing else, `bar-wallpaper.qml` adds Route B's masked backdrop, and
`bar-blur.qml` asks niri for the blur instead. Watch niri's own CPU while the
last one is up; watch the probe's while the first two are.

## captures

  01  the answer to what niri blurs: two identical patches over a red
      terminal, the upper one asking for blur. It shows the WALLPAPER.
  02  the four treatments over a #101014 window, at 1:1.
  03  the fillet (top row) and the panel's bottom left corner (bottom row) at
      12x, for each treatment. This is the picture the recommendation rests on.
  05  the same four with `xray false` forced on the probe namespace, over a
      terminal full of text: 1 and 2 blur the TEXT, which is the honest glass,
      and 3 goes on showing the wallpaper because that is all it knows.

## What the probes established

1. niri's blur is XRAY, and that is the default. A surface asking for blur
   through ext-background-effect gets the BACKGROUND LAYER blurred -- the
   wallpaper -- and nothing else. Not the window behind it. Capture 01: a red
   terminal filling the screen, and the patch that asked for blur shows sky.
   In the source, `xray` is `Option<bool>` and unset resolves to true whenever
   any background effect is active, protocol-requested blur included.

2. Which is why Route B is not an approximation. A Gaussian at sigma 9.5 with
   saturation 1.2, over the same wallpaper frame, reproduces niri's dual Kawase
   (passes 2, offset 3.0) to an RMS of 2.65 out of 255, and the panel drawn
   with it landed within 2 levels of the panel niri blurred beside it.

3. Route A cannot work here. ScreencopyView's only source on niri is a whole
   OUTPUT, wlr-screencopy copies what was composited, and there is no way to
   leave the requesting client out -- so the panel captures itself.

4. The blur region is never antialiased and never can be. niri turns the
   wl_region into damage rects and rounds every extremity with
   `to_physical_precise_round`. There is no coverage term in that path.

5. `xray false` on a layer rule switches to the experimental framebuffer path
   and gives honest glass -- capture 05, where the text behind the panel is
   properly blurred away. niri documents that path as experimental, with the
   effect disappearing during open/close animations and while dragging a tiled
   window, which is most of what the shell's popouts do.

Handy: niri reads `~/.config/niri/local.kdl` as an optional include, so a
layer rule can be tried without touching the config in the repo at all.
