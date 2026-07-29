# ~/.config/fish/functions/fish_greeting.fish
# ==============================================================================
# Olvex Shell — Terminal Welcome & Greeting Screen
# Motif: Static Olvex Brand Logo (Perfectly Bottom-Aligned) + 2-Column Info
# ==============================================================================

function fish_greeting --description "Olvex M3 Expressive Welcome Screen"
    # Skip greeting on TTY console (/dev/tty1-6) where 24-bit ANSI/braille isn't supported
    if test "$TERM" = "linux"; or not set -q WAYLAND_DISPLAY
        return
    end

    echo

    set -l scheme_file "$HOME/.local/state/olvex/scheme.json"
    if not test -f "$scheme_file"
        set scheme_file "$HOME/.cache/olvex/scheme.json"
    end

    # ── Dynamic System Accent Sync for System Info Metadata ───────────────
    if test -f "$scheme_file"; and command -v python3 >/dev/null 2>&1
        python3 -c "
import json, os, math

scheme_path = '$scheme_file'
config_path = os.path.expanduser('~/.config/fastfetch/config.jsonc')

try:
    with open(scheme_path) as f:
        colours = json.load(f).get('colours', {})
    
    primary = colours.get('primary', '675fff').lstrip('#')
    secondary = colours.get('secondary', 'ff8a5b').lstrip('#')
    tertiary = colours.get('tertiary', '8eacbb').lstrip('#')
    fg = colours.get('onBackground', 'dde8e2').lstrip('#')
    muted = colours.get('onSurfaceVariant', 'a3aea8').lstrip('#')
    
    def hex_to_rgb(h):
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
    
    pr, pg, pb = hex_to_rgb(primary)
    sr, sg, sb = hex_to_rgb(secondary)
    tr, tg, tb = hex_to_rgb(tertiary)
    fgr, fgg, fgb = hex_to_rgb(fg)
    mr, mg, mb = hex_to_rgb(muted)
    
    # Bottom-Aligned Rasterizer (34x9 braille grid = 36 subpixel rows, exactly 12 total lines)
    w_chars, h_chars = 34, 9
    w_dots, h_dots = 68, 36
    grid = [[(0, 0) for _ in range(w_dots)] for _ in range(h_dots)]

    def dist_to_segment(px, py, x1, y1, x2, y2):
        l2 = (x1-x2)**2 + (y1-y2)**2
        if l2 == 0: return math.hypot(px-x1, py-y1)
        t = max(0, min(1, ((px-x1)*(x2-x1) + (py-y1)*(y2-y1)) / l2))
        return math.hypot(px - (x1 + t*(x2-x1)), py - (y1 + t*(y2-y1)))

    for r in range(h_dots):
        for c in range(w_dots):
            px = c * (240 / w_dots)
            py = r * (240 / h_dots)
            d1 = dist_to_segment(px, py, 55, 185, 95, 30)
            d2 = dist_to_segment(px, py, 185, 185, 145, 30)
            if d1 <= 16: grid[r][c] = (1, 1)
            elif d2 <= 16: grid[r][c] = (1, 2)
            elif 205 <= py <= 238 and 20 <= px <= 220:
                if abs(py - (220 - 14 * math.sin((px - 120) * math.pi / 45))) <= 4.5:
                    grid[r][c] = (1, 3)

    dot_map = [[0x01, 0x08], [0x02, 0x10], [0x04, 0x20], [0x40, 0x80]]
    fastfetch_lines = []

    def rgb_fg(r, g, b): return f'\033[38;2;{r};{g};{b}m'

    for ch_r in range(h_chars):
        ff_line = ''
        ratio = ch_r / (h_chars - 1)
        # Static Brand Indigo Gradient
        lr, lg, lb = int(138*(1-ratio) + 85*ratio), int(124*(1-ratio) + 65*ratio), int(255*(1-ratio) + 245*ratio)
        # Static Brand Coral Gradient
        rr, rg, rb = int(255*(1-ratio) + 255*ratio), int(176*(1-ratio) + 110*ratio), int(136*(1-ratio) + 50*ratio)
        
        for ch_c in range(w_chars):
            c_start = ch_c * 2
            code = 0x2800
            cell_type = 0
            for dr in range(4):
                for dc in range(2):
                    v, t = grid[ch_r*4 + dr][c_start + dc]
                    if v == 1: code |= dot_map[dr][dc]; cell_type = t
            if code == 0x2800: ff_line += ' '
            else:
                if cell_type == 1: ff_line += f'{rgb_fg(lr, lg, lb)}{chr(code)}\033[0m'
                elif cell_type == 2: ff_line += f'{rgb_fg(rr, rg, rb)}{chr(code)}\033[0m'
                else:
                    cr = ch_c / (w_chars - 1)
                    wr, wg, wb = int(110*(1-cr) + 210*cr), int(210*(1-cr) + 150*cr), int(251*(1-cr) + 225*cr)
                    ff_line += f'{rgb_fg(wr, wg, wb)}{chr(code)}\033[0m'
        fastfetch_lines.append(ff_line)

    logo_src = '\n'.join(fastfetch_lines) + f'\n\n     \033[1;38;2;{fgr};{fgg};{fgb}mO L V E X\033[0m\n     \033[38;2;{mr};{mg};{mb}mHyprland · Wayland Shell\033[0m'

    ff_config = {
        '$schema': 'https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json',
        'logo': {'type': 'data', 'source': logo_src, 'padding': {'right': 2}},
        'display': {
            'separator': '  ',
            'color': {'keys': f'38;2;{pr};{pg};{pb}', 'output': f'38;2;{fgr};{fgg};{fgb}'}
        },
        'modules': [
            {'type': 'title', 'color': {'user': f'38;2;{pr};{pg};{pb}', 'at': f'38;2;{mr};{mg};{mb}', 'host': f'38;2;{sr};{sg};{sb}'}},
            {'type': 'separator', 'string': '─'},
            {'type': 'os', 'key': '󰣇 OS       ', 'keyColor': f'38;2;{pr};{pg};{pb}'},
            {'type': 'host', 'key': '󰌢 Host     ', 'keyColor': f'38;2;{sr};{sg};{sb}', 'format': '{2}'},
            {'type': 'kernel', 'key': '󰌽 Kernel   ', 'keyColor': f'38;2;{tr};{tg};{tb}'},
            {'type': 'wm', 'key': '󰍹 Desktop  ', 'keyColor': f'38;2;{pr};{pg};{pb}'},
            {'type': 'shell', 'key': '󰞷 Shell    ', 'keyColor': f'38;2;{sr};{sg};{sb}'},
            {'type': 'packages', 'key': '󰏖 Packages ', 'keyColor': f'38;2;{tr};{tg};{tb}'},
            {'type': 'memory', 'key': '󰍛 Memory   ', 'keyColor': f'38;2;{pr};{pg};{pb}'},
            {'type': 'uptime', 'key': '󰅐 Uptime   ', 'keyColor': f'38;2;{sr};{sg};{sb}'},
            'break',
            {'type': 'colors', 'symbol': 'circle'}
        ]
    }
    
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, 'w') as f:
        json.dump(ff_config, f, indent=2)
except Exception as e:
    pass
" 2>/dev/null
    end

    if command -v fastfetch >/dev/null 2>&1
        if test "$TERM" = "linux"
            set -l tty_logo (printf "          \033[1;34m///\033[0m       \033[1;33m\\\\\\\\\\\033[0m\n         \033[1;34m///\033[0m         \033[1;33m\\\\\\\\\\\033[0m\n        \033[1;34m///\033[0m           \033[1;33m\\\\\\\\\\\033[0m\n       \033[1;34m///\033[0m             \033[1;33m\\\\\\\\\\\033[0m\n     \033[1;36m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m\n\n     \033[1;37mO L V E X\033[0m\n     \033[0;37mHyprland \u00b7 Wayland Shell\u001b[0m\n")
            fastfetch --logo-type data --logo "$tty_logo"
        else
            fastfetch
        end
        echo
        return
    end

    # ── Token Defaults (Fallback if fastfetch is not available) ───────────────
    set -l c_left "675fff"
    set -l c_right "ff8a5b"
    set -l c_tertiary "6ed2fb"
    set -l c_fg "dde8e2"
    set -l c_muted "a3aea8"

    # ── Olvex Motif Rendering (TTY vs GUI) ──────────────────────────────────
    if test "$TERM" = "linux"
        echo -s "          " (set_color blue --bold) "///" (set_color normal) "       " (set_color yellow --bold) "\\\\\\\\" (set_color normal)
        echo -s "         " (set_color blue --bold) "///" (set_color normal) "         " (set_color yellow --bold) "\\\\\\\\" (set_color normal)
        echo -s "        " (set_color blue --bold) "///" (set_color normal) "           " (set_color yellow --bold) "\\\\\\\\" (set_color normal)
        echo -s "       " (set_color blue --bold) "///" (set_color normal) "             " (set_color yellow --bold) "\\\\\\\\" (set_color normal)
        echo -s "     " (set_color cyan --bold) "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" (set_color normal)
    else
        echo -s "         " (set_color 8c78ff) "⢀⣴⣿⣿⡷" (set_color normal) "  " (set_color ffaa78) "⠰⣿⣿⣷⣄" (set_color normal)
        echo -s "        " (set_color 816dfd) "⣠⣿⣿⣿⠏" (set_color normal) "    " (set_color ff9e6a) "⠈⢿⣿⣿⣧⡀" (set_color normal)
        echo -s "      " (set_color 7662fb) "⢀⣼⣿⣿⡿⠁" (set_color normal) "       " (set_color ff925c) "⠹⣿⣿⣿⣄" (set_color normal)
        echo -s "      " (set_color 6b57f9) "⠻⠿⠿⠋" (set_color normal) "          " (set_color ff864e) "⠈⠻⠿⠿⠃" (set_color normal)
        echo -s "   " (set_color 6ed2fb) "⠐⠒⠉⠉⠉⁁⠒⠤⠄ ⠠⠄⠒⠈⠉⠉⠉⠒⠠⠄ ⠠⠤⠒" (set_color normal)
    end
    echo
    echo -s (set_color --bold $c_fg) "   O L V E X" (set_color normal)
    echo -s (set_color $c_muted) "   Hyprland Shell" (set_color normal)
    echo
end
