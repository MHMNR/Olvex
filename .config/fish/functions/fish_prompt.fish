# ~/.config/fish/functions/fish_prompt.fish
# ==============================================================================
# Olvex Shell — Custom Fast Prompt Function
# Uses M3 color-engine tokens dynamically read from scheme.json
# ==============================================================================

function fish_prompt --description "Olvex M3 Expressive prompt"
    set -l last_status $status

    # ── Token Defaults (Fallback to live scheme values) ───────────────────────
    set -l c_fg "dde8e2"
    set -l c_primary "9ed1c0"
    set -l c_secondary "b2ccc2"
    set -l c_error "fa746f"
    set -l c_muted "a3aea8"

    set -l scheme_file "$HOME/.local/state/olvex/scheme.json"
    if not test -f "$scheme_file"
        set scheme_file "$HOME/.cache/olvex/scheme.json"
    end

    if test -f "$scheme_file"; and command -v python3 >/dev/null 2>&1
        set -l parsed (python3 -c "
import json
try:
    with open('$scheme_file') as f:
        d = json.load(f).get('colours', {})
    print(f\"{d.get('onBackground', 'dde8e2')}:{d.get('primary', '9ed1c0')}:{d.get('secondary', 'b2ccc2')}:{d.get('error', 'fa746f')}:{d.get('onSurfaceVariant', 'a3aea8')}\")
except Exception:
    pass
" 2>/dev/null)
        if test -n "$parsed"
            set -l parts (string split ":" -- $parsed)
            set c_fg $parts[1]
            set c_primary $parts[2]
            set c_secondary $parts[3]
            set c_error $parts[4]
            set c_muted $parts[5]
        end
    end

    # Ensure leading #
    if not string match -q "#*" $c_fg; set c_fg "#$c_fg"; end
    if not string match -q "#*" $c_primary; set c_primary "#$c_primary"; end
    if not string match -q "#*" $c_secondary; set c_secondary "#$c_secondary"; end
    if not string match -q "#*" $c_error; set c_error "#$c_error"; end
    if not string match -q "#*" $c_muted; set c_muted "#$c_muted"; end

    set -l pwd_str (prompt_pwd)

    # Git Branch Check
    set -l git_str ""
    if command -v git >/dev/null 2>&1
        set -l branch (command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
        if test -n "$branch"
            set git_str (set_color $c_primary)"  "$branch(set_color normal)
        end
    end

    # Command Duration (> 2000ms)
    set -l dur_str ""
    if test -n "$CMD_DURATION"; and test $CMD_DURATION -gt 2000
        set -l duration_sec (math -s1 "$CMD_DURATION / 1000")
        set dur_str (set_color $c_muted)" ("$duration_sec"s)"(set_color normal)
    end

    set -l status_color (test $last_status -eq 0; and echo $c_secondary; or echo $c_error)

    # Clean single-line prompt: show path & git info inline before ❯ symbol
    if test "$pwd_str" != "~"
        echo -n -s (set_color $c_fg) $pwd_str (set_color normal) " "
    end

    if test -n "$git_str"
        echo -n -s $git_str " "
    end

    if test -n "$dur_str"
        echo -n -s $dur_str " "
    end

    echo -n -s (set_color $status_color) "❯ " (set_color normal)
end
