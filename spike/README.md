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
