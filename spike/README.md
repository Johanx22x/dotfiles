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
