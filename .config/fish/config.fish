# ~/.config/fish/config.fish
# ==============================================================================
# Olvex Shell — Fish Shell Main Configuration
# Dynamic colors synced from Olvex M3 color engine (~/.local/state/olvex/scheme.json)
# ==============================================================================

# Disable default built-in greeting (handled by fish_greeting function)
set -g fish_greeting

# Interactive session setup
if status is-interactive
    # Default to emacs keybindings
    fish_default_key_bindings

    # ── Dynamic Olvex Palette Sync ──────────────────────────────────────────
    function _olvex_sync_colors --description "Sync fish colors with Olvex M3 scheme.json"
        set -l scheme_file "$HOME/.local/state/olvex/scheme.json"
        if not test -f "$scheme_file"
            set scheme_file "$HOME/.cache/olvex/scheme.json"
        end

        if test -f "$scheme_file"; and command -v python3 >/dev/null 2>&1
            set -l color_data (python3 -c "
import json
try:
    with open('$scheme_file') as f:
        d = json.load(f).get('colours', {})
    print('primary=' + d.get('primary', '9ed1c0'))
    print('secondary=' + d.get('secondary', 'b2ccc2'))
    print('background=' + d.get('background', '0a0f0d'))
    print('onBackground=' + d.get('onBackground', 'dde8e2'))
    print('muted=' + d.get('onSurfaceVariant', 'a3aea8'))
    print('error=' + d.get('error', 'fa746f'))
except Exception:
    pass
" 2>/dev/null)

            for line in $color_data
                set -l kv (string split "=" -- $line)
                set -l key $kv[1]
                set -l val $kv[2]
                if not string match -q "#*" $val
                    set val "#$val"
                end

                switch $key
                    case primary
                        set -g fish_color_command $val
                        set -g fish_color_keyword $val
                        set -g fish_color_search_match --background=$val
                    case secondary
                        set -g fish_color_quote $val
                        set -g fish_color_option $val
                    case onBackground
                        set -g fish_color_normal $val
                    case muted
                        set -g fish_color_comment $val
                        set -g fish_color_autosuggestion $val
                    case error
                        set -g fish_color_error $val
                end
            end
        end
    end

    _olvex_sync_colors

    # ── Development & Workflow Abbreviations ────────────────────────────────
    abbr -a g git
    abbr -a gs "git status"
    abbr -a gd "git diff"
    abbr -a gl "git log --oneline -n 15"
    abbr -a hypr-reload "hyprctl reload"
    abbr -a olvex-restart "./scripts/olvex shell restart"
end
