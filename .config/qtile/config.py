# Copyright (c) 2010 Aldo Cortesi
# Copyright (c) 2010, 2014 dequis
# Copyright (c) 2012 Randall Ma
# Copyright (c) 2012-2014 Tycho Andersen
# Copyright (c) 2012 Craig Barnes
# Copyright (c) 2013 horsik
# Copyright (c) 2013 Tao Sauvage
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from libqtile import bar, layout, widget, hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal

from os import path, listdir
import subprocess
import get_colors

@hook.subscribe.startup_once
def autostart():
    subprocess.call([path.join(path.expanduser('-'), '.config', 'qtile', 'autostart.sh')])


mod = "mod4"
terminal = guess_terminal()

# Theme
default_theme = "dark-grey"


keys = [

    Key([mod], "j", lazy.layout.down()),
    Key([mod], "k", lazy.layout.up()),
    Key([mod], "h", lazy.layout.left()),
    Key([mod], "l", lazy.layout.right()),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down()),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up()),
    Key([mod, "shift"], "h", lazy.layout.shuffle_left()),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right()),
    Key([mod, "mod1"], "j", lazy.layout.flip_down()),
    Key([mod, "mod1"], "k", lazy.layout.flip_up()),
    Key([mod, "mod1"], "h", lazy.layout.flip_left()),
    Key([mod, "mod1"], "l", lazy.layout.flip_right()),
    Key([mod, "control"], "j", lazy.layout.grow_down()),
    Key([mod, "control"], "k", lazy.layout.grow_up()),
    Key([mod, "control"], "h", lazy.layout.grow_left()),
    Key([mod, "control"], "l", lazy.layout.grow_right()),
    Key([mod, "shift"], "n", lazy.layout.normalize()),
    Key([mod], "Return", lazy.layout.toggle_split()),



    # A list of available commands that can be bound to keys can be found
    # at https://docs.qtile.org/en/latest/manual/config/lazy.html
    # Switch between windows
    #Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    #Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    #Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    #Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    #Key([mod], "space", lazy.layout.next(), desc="Move window focus to other window"),
    ## Move windows between left/right columns or move up/down in current stack.
    ## Moving out of range in Columns layout will create new column.
    #Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"),
    #Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Move window to the right"),
    #Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    #Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
    ## Grow windows. If current window is on the edge of screen and direction
    ## will be to screen edge - window would shrink.
    #Key([mod, "control"], "h", lazy.layout.grow_left(), desc="Grow window to the left"),
    #Key([mod, "control"], "l", lazy.layout.grow_right(), desc="Grow window to the right"),
    #Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
    #Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    #Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes
    Key(
        [mod, "shift"],
        "Return",
        lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack",
    ),
    
    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod], "w", lazy.window.kill(), desc="Kill focused window"),
    Key([mod, "control"], "r", lazy.reload_config(), desc="Reload the config"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod], "r", lazy.spawncmd(), desc="Spawn a command using a prompt widget"),

    # ------------ PROGRAMS ------------

    # Browser
    Key([mod], "f", lazy.spawn("firefox")),

    # Screen shot
    Key([mod], "s", lazy.spawn("scrot -q 100")),
    Key([mod, "shift"], "s", lazy.spawn("scrot -q 70")),

    # Visual Studio
    Key([mod], "c", lazy.spawn("code")),

    # Screen shot
    Key([mod], "e", lazy.spawn("thunar")),

    # Sublime Text
    Key([mod], "t", lazy.spawn("subl")),

    # Menu
    Key([mod], "m", lazy.spawn("rofi -show drun")),

    # Lock Screen
    # Key([mod, "shift"], "l", lazy.spawn("killall qtile")),

    # All apps
    Key([mod, "control"], "m", lazy.spawn("rofi -show run")),

    # Window Nav
    Key([mod, "shift"], "m", lazy.spawn("rofi -show")),

    # Run terminal
    Key([mod], "Return", lazy.spawn("wezterm")),

    # Language select
    Key([mod], "space", lazy.spawn("lang")),
    
    # Power option
    Key([mod, "shift"], "p", lazy.spawn("power-options")),

    # Cmus next song
    Key([], "XF86AudioNext", lazy.spawn("playerctl next"), lazy.spawn("sas")),

    # Cmus previous song
    Key([], "XF86AudioPrev", lazy.spawn("playerctl previous"), lazy.spawn("sas")),

    # Cmus pause song
    Key([], "XF86AudioPlay", lazy.spawn("playerctl play-pause"), lazy.spawn("sas")),

    # ------------ Hardware Configs ------------

    # Volume
    Key([], "XF86AudioLowerVolume", lazy.spawn(
        "pactl set-sink-volume @DEFAULT_SINK@ -5%"
    )),
    Key([], "XF86AudioRaiseVolume", lazy.spawn(
        "pactl set-sink-volume @DEFAULT_SINK@ +5%"
    )),
    Key([], "XF86AudioPause", lazy.spawn(
        "pactl set-sink-volume @DEFAULT_SINK@ +5%"
    ), lazy.spawn("sas")),
    Key([], "XF86AudioMute", lazy.spawn(
        "pactl set-sink-mute @DEFAULT_SINK@ toggle"
    )),

    # Brightness
    Key([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +10%")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 10%-")),
    
]

# groups = [Group(i) for i in ["WWW", "DEV", "TERM", "MISC"]]

groups = [Group(i) for i in ["   ", "   ", "   ", "   ", "   ", "  "]]

for i, group in enumerate(groups):
    actual_key = str(i + 1)
    keys.extend([
        # Switch to workspace N
        Key([mod], actual_key, lazy.group[group.name].toscreen()),
        # Send window to workspace N
        Key([mod, "shift"], actual_key, lazy.window.togroup(group.name))
    ])

layout_conf = {
    # 'border_focus': '#F07178',
    'border_width': 0,
    'margin': 4
}

tree_layout_config = {
    
    # Section configs
    'section_padding': 4,
    'section_fg': '#ffffff',
    'section_fontsize': 16,
    'sections': ['Main'],

    # Tab configs
    'font': 'UbuntuMono Nerd Font',
    'bg_color': '#000000',
    'padding_x': 4,
    'padding_y': 4,
    'vspace': 4,
}

layouts = [
    # layout.Columns(border_focus_stack=["#d75f5f", "#8f3d3d"], border_width=4),
    layout.Max(**layout_conf),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    layout.Bsp(**layout_conf),
    # layout.Matrix(**layout_conf),
    layout.MonadTall(**layout_conf),
    # layout.MonadWide(),
    # layout.RatioTile(),
    # layout.Tile(),
    # layout.TreeTab(**tree_layout_config),
    # layout.VerticalTile(),
    # layout.Zoomy(),
]


widget_defaults = {
    'font': 'UbuntuMono Nerd Font',
    'fontsize': 16,
    'padding': 1,
}

extension_defaults = widget_defaults.copy()

text_box = lambda fontsize=20: {
    'font': 'Ubuntu Mono',
    'fontsize': fontsize,
    'padding': 5
},

colors = get_colors.get_colors()

screens = [
    Screen(
        top=bar.Bar(
            [

                widget.Sep(
                    linewidth=0,
                    padding=7,
                    background=colors.color4,
                ),
                
                widget.Image(
                    background=colors.color4,
                    filename="~/Documents/My_configs/IMG/arch_logo.png",
                ),
                
                widget.TextBox(
                    background=colors.color4,
                    foreground=colors.background,
                    font='Ubuntu Mono',
                    fontsize=20,
                    padding=0,
                    text='\ue0b2'  # Icon: nf-fa-feed
                ),


                # widget.Image(
                #     filename="~/Documents/My_configs/IMG/bar5.png"
                # ),

                widget.GroupBox(
                    foreground=colors.color1,
                    background=colors.background,
                    font='UbuntuMono Nerd Font',
                    fontsize=19,
                    margin_y=3,
                    margin_x=0,
                    padding_y=8,
                    padding_x=5,
                    borderwidth=1,
                    active=colors.foreground,
                    inactive=colors.foreground,
                    rounded=False,
                    highlight_method='text',
                    this_current_screen_border=colors.color1,
                    this_screen_border=colors.color1,
                    other_current_screen_border=["#111111","#0f101a"],
                    other_screen_border=["#0f101a","#0f101a"],
                ),
                
                widget.WindowName(
                    foreground=colors.color1,
                    background=colors.background,
                    font='UbuntuMono Nerd Font Bold',
                    fontsize=14,
                ),

                widget.TextBox(
                    background=colors.background,
                    foreground=colors.color8,
                    font='Ubuntu Mono',
                    fontsize=23,
                    padding=0,
                    text='\ue0b2'  # Icon: nf-fa-feed
                ),

                widget.TextBox(
                    background=colors.color8,
                    foreground=colors.foreground,
                    font='Ubuntu Mono',
                    fontsize=23,
                    padding=2,
                    text='墳'  # Icon: nf-fa-feed
                ),

                widget.PulseVolume(
                    background=colors.color8,
                    foreground=colors.foreground,
                    cardid=2,
                    device='default',
                    font='UbuntuMono Nerd Font',
                    emoji=False,
                    update_interval=0.1,
                    fmt="{}",
                ),

                widget.Sep(
                    padding=7,
                    background=colors.color8,
                    linewidth=0,
                ),

                widget.Cmus(
                    play_color=colors.foreground,
                    noplay_color=colors.background,
                    max_chars=40,
                    update_interval=0.5,
                    background=colors.color8,
                ),

                widget.TextBox(
                    background=colors.color8,
                    foreground=colors.color7,
                    font='Ubuntu Mono',
                    fontsize=23,
                    padding=0,
                    text='\ue0b2'  # Icon: nf-fa-feed
                ),

                widget.Systray(
                    foreground=colors.foreground,
                    background=colors.color7,
                ),

                widget.Sep(
                    padding=7,
                    background=colors.color7,
                    linewidth=0,
                ),

                widget.TextBox(
                    background=colors.color7,
                    foreground=colors.color1,
                    font='Ubuntu Mono',
                    fontsize=23,
                    padding=0,
                    text='\ue0b2'  # Icon: nf-fa-feed
                ),

                widget.CurrentLayoutIcon(
                    scale=0.65,
                    foreground=colors.background,
                    background=colors.color1,
                ),
                widget.CurrentLayout(
                    foreground=colors.background,
                    background=colors.color1,
                ),

                widget.Sep(
                    padding=7,
                    background=colors.color1,
                    linewidth=0,
                ),

                widget.TextBox(
                    background=colors.color1,
                    foreground=colors.color4,
                    font='Ubuntu Mono',
                    fontsize=23,
                    padding=0,
                    text='\ue0b2'  # Icon: nf-fa-feed
                ),
                
                widget.Chord(
                    chords_colors={
                        "launch": ("#ff0000", "#ffffff"),
                    },
                    name_transform=lambda name: name.upper(),
                ),
                # widget.TextBox("default config", name="default"),
                # widget.TextBox("Press &lt;M-r&gt; to spawn", foreground="#d75f5f"),
                
                widget.Clock(
                    padding=5,
                    format='  %d/%m/%Y - %H:%M ',
                    foreground=colors.background,
                    background=colors.color4,
                ),
            ],
            26,
            opacity=0.80,
            margin=5,
            # border_width=[2, 0, 2, 0],  # Draw top and bottom borders
            # border_color=["ff00ff", "000000", "ff00ff", "000000"]  # Borders are magenta
        ),
    ),
    Screen(
        top=bar.Bar(
            [
                widget.GroupBox(
                    foreground=["#f1ffff","#f1ffff"],
                    background=["#0f101a","#0f101a"],
                    font='UbuntuMono Nerd Font',
                    fontsize=19,
                    margin_y=3,
                    margin_x=0,
                    padding_y=8,
                    padding_x=5,
                    borderwidth=1,
                    active=["#f1ffff","#f1ffff"],
                    inactive=["#f1ffff","#f1ffff"],
                    rounded=False,
                    highlight_method='block',
                    this_current_screen_border=["#F07178","#F07178"],
                    this_screen_border=["#5c5c5c","#5c5c5c"],
                    other_current_screen_border=["#0f101a","#0f101a"],
                    other_screen_border=["#0f101a","#0f101a"],
                ),
                # widget.Prompt(),
                widget.WindowName(
                    foreground=["#F07178","#F07178"],
                    background=["#0f101a","#0f101a"],
                    font='UbuntuMono Nerd Font Bold',
                    fontsize=14,
                ),

                widget.Image(
                    filename="~/Documents/My_configs/IMG/bar4.png"
                ),

                widget.TextBox(
                    foreground=["#0f101a", "#0f101a"],
                    background=["#ffd47e", "#ffd47e"],
                    font='Ubuntu Mono',
                    fontsize=25,
                    padding=5,
                    text=' '  # Icon: nf-fa-download
                ),

                

                widget.Sep(
                    linewidth=0,
                    padding=5,
                    background=["#ffd47e","#ffd47e"], 
                ),

                

                widget.Image(
                    filename="~/Documents/My_configs/IMG/bar3.png"
                ),                

                widget.TextBox(
                    background=["#fb9f7f", "#fb9f7f"],
                    foreground=["#0f101a", "#0f101a"],
                    font='Ubuntu Mono',
                    fontsize=20,
                    padding=5,
                    text=' '  # Icon: nf-fa-feed
                ),

                widget.Net(
                    background=["#fb9f7f", "#fb9f7f"],
                    foreground=["#0f101a", "#0f101a"],
                    interface="wlan0"
                ),
                
                widget.Sep(
                    linewidth=0,
                    padding=5,
                    background=["#fb9f7f","#fb9f7f"], 
                ),
                
                widget.Image(
                    filename="~/Documents/My_configs/IMG/bar2.png"
                ),

                widget.CurrentLayoutIcon(
                    scale=0.65,
                    foreground=["#0f101a","#0f101a"],
                    background=["#F07178","#F07178"],
                ),
                widget.CurrentLayout(
                    foreground=["#0f101a","#0f101a"],
                    background=["#F07178","#F07178"],
                ),

                widget.Sep(
                    linewidth=0,
                    padding=5,
                    background=["#F07178","#F07178"],  
                ),

                widget.Image(
                    filename="~/Documents/My_configs/IMG/bar1.png"
                ),
                
                widget.Chord(
                    chords_colors={
                        "launch": ("#ff0000", "#ffffff"),
                    },
                    name_transform=lambda name: name.upper(),
                ),
                # widget.TextBox("default config", name="default"),
                # widget.TextBox("Press &lt;M-r&gt; to spawn", foreground="#d75f5f"),
                
                widget.Clock(
                    background=["#a151d3","#a151d3"],
                    foreground=["#0f101a","#0f101a"],
                    padding=5,
                    format='  %d/%m/%Y - %H:%M '
                ),
            ],
            26,
            opacity=0.80,
            margin=5,
            
            # border_color=["ff00ff", "000000", "ff00ff", "000000"]  # Borders are magenta
        ),
    ),
]

# Drag floating layouts.
mouse = [
    Drag(
        [mod],
        "Button1",
        lazy.window.set_position_floating(),
        start=lazy.window.get_position()
    ),
    Drag(
        [mod],
        "Button3",
        lazy.window.set_size_floating(),
        start=lazy.window.get_size()
    ),
    Click([mod], "Button2", lazy.window.bring_to_front())
]


dgroups_key_binder = None
dgroups_app_rules = []  # type: list
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
floating_layout = layout.Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
    ], 
    border_focus="#ffffff"
)
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

# If things like steam games want to auto-minimize themselves when losing
# focus, should we respect this or not?
auto_minimize = True

# When using the Wayland backend, this can be used to configure input devices.
wl_input_rules = None

# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
