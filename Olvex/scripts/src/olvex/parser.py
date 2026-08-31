import argparse
import sys

from olvex.subcommands import (
    emoji,
    install,
    record,
    scheme,
    screenshot,
    update,
    wallpaper,
)
from olvex.utils.dots.manifest import Manifest
from olvex.utils.dots.packages import AUR_HELPERS
from olvex.utils.dots.source import DotsSource
from olvex.utils.io import warn
from olvex.utils.paths import wallpapers_dir
from olvex.utils.scheme import get_scheme_names, scheme_variants
from olvex.utils.wallpaper import get_wallpaper


def parse_args() -> tuple[argparse.ArgumentParser, argparse.Namespace]:
    parser = argparse.ArgumentParser(prog="olvex", description="Main control script for the Olvex dotfiles")
    parser.add_argument("-v", "--version", action="store_true", help="print the current version")

    # Add subcommand parsers
    command_parser = parser.add_subparsers(
        title="subcommands", description="valid subcommands", metavar="COMMAND", help="the subcommand to run"
    )

    # Create parser for scheme opts
    scheme_parser = command_parser.add_parser("scheme", help="manage the colour scheme")
    scheme_command_parser = scheme_parser.add_subparsers(title="subcommands")

    list_parser = scheme_command_parser.add_parser("list", help="list available schemes")
    list_parser.set_defaults(cls=scheme.List)
    list_parser.add_argument("-n", "--names", action="store_true", help="list scheme names")
    list_parser.add_argument("-f", "--flavours", action="store_true", help="list scheme flavours")
    list_parser.add_argument("-m", "--modes", action="store_true", help="list scheme modes")
    list_parser.add_argument("-v", "--variants", action="store_true", help="list scheme variants")

    get_parser = scheme_command_parser.add_parser("get", help="get scheme properties")
    get_parser.set_defaults(cls=scheme.Get)
    get_parser.add_argument("-n", "--name", action="store_true", help="print the current scheme name")
    get_parser.add_argument("-f", "--flavour", action="store_true", help="print the current scheme flavour")
    get_parser.add_argument("-m", "--mode", action="store_true", help="print the current scheme mode")
    get_parser.add_argument("-v", "--variant", action="store_true", help="print the current scheme variant")

    set_parser = scheme_command_parser.add_parser("set", help="set the current scheme")
    set_parser.set_defaults(cls=scheme.Set)
    set_parser.add_argument("--notify", action="store_true", help="send a notification on error")
    set_parser.add_argument("-r", "--random", action="store_true", help="switch to a random scheme")
    set_parser.add_argument("-n", "--name", choices=get_scheme_names(), help="the name of the scheme to switch to")
    set_parser.add_argument("-f", "--flavour", help="the flavour to switch to")
    set_parser.add_argument("-m", "--mode", choices=["dark", "light"], help="the mode to switch to")
    set_parser.add_argument("-v", "--variant", choices=scheme_variants, help="the variant to switch to")

    # Create parser for screenshot opts
    screenshot_parser = command_parser.add_parser("screenshot", help="take a screenshot")
    screenshot_parser.set_defaults(cls=screenshot.Command)
    screenshot_parser.add_argument("-r", "--region", nargs="?", const="slurp", help="take a screenshot of a region")
    screenshot_parser.add_argument(
        "-f", "--freeze", action="store_true", help="freeze the screen while selecting a region"
    )

    # Create parser for record opts
    record_parser = command_parser.add_parser("record", help="start a screen recording")
    record_parser.set_defaults(cls=record.Command)
    record_parser.add_argument("-r", "--region", nargs="?", const="slurp", help="record a region")
    record_parser.add_argument("-s", "--sound", action="store_true", help="record audio")
    record_parser.add_argument("-p", "--pause", action="store_true", help="pause/resume the recording")
    record_parser.add_argument("-c", "--clipboard", action="store_true", help="copy recording path to clipboard")

    # Create parser for emoji-picker opts
    emoji_parser = command_parser.add_parser("emoji", help="emoji/glyph utilities")
    emoji_parser.set_defaults(cls=emoji.Command)
    emoji_parser.add_argument("-p", "--picker", action="store_true", help="open the emoji/glyph picker")
    emoji_parser.add_argument("-f", "--fetch", action="store_true", help="fetch emoji/glyph data from remote")

    # Create parser for wallpaper opts
    wallpaper_parser = command_parser.add_parser("wallpaper", help="manage the wallpaper")
    wallpaper_parser.set_defaults(cls=wallpaper.Command)
    wallpaper_parser.add_argument(
        "-p", "--print", nargs="?", const=get_wallpaper(), metavar="PATH", help="print the scheme for a wallpaper"
    )
    wallpaper_parser.add_argument(
        "-r", "--random", nargs="?", const=wallpapers_dir, metavar="DIR", help="switch to a random wallpaper"
    )
    wallpaper_parser.add_argument("-f", "--file", help="the path to the wallpaper to switch to")
    wallpaper_parser.add_argument("-n", "--no-filter", action="store_true", help="do not filter by size")
    wallpaper_parser.add_argument(
        "-t",
        "--threshold",
        default=0.8,
        help="the minimum percentage of the largest monitor size the image must be greater than to be selected",
    )
    wallpaper_parser.add_argument(
        "-N",
        "--no-smart",
        action="store_true",
        help="do not automatically change the scheme mode/variant based on wallpaper colour",
    )
    wallpaper_parser.add_argument(
        "--scheme-mode",
        choices=["dark", "light"],
        dest="scheme_mode",
        default=None,
        help="force light/dark palette mode (overrides smart mode pick; keeps smart variant)",
    )
    wallpaper_parser.add_argument(
        "-v",
        "--variant",
        dest="scheme_variant",
        default=None,
        help="force a specific variant (overrides smart mode variant pick)",
    )

    # Create parser for install opts
    install_parser = command_parser.add_parser(
        "install",
        help="install the Olvex dotfiles",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    install_parser.set_defaults(cls=install.Command)
    install_parser.add_argument("--aur-helper", choices=AUR_HELPERS, help="the AUR helper to use")
    install_parser.add_argument(
        "--enable-components", metavar="LIST", help="comma-separated list of components to enable"
    )
    install_parser.add_argument(
        "--disable-components", metavar="LIST", help="comma-separated list of components to disable"
    )
    install_parser.add_argument("--noconfirm", action="store_true", help="use defaults for all prompts")
    install_parser.add_argument(
        "--drivers",
        dest="drivers",
        action="store_true",
        default=None,
        help="automatically detect and install hardware drivers (GPU, audio, microcode, bluetooth)",
    )
    install_parser.add_argument(
        "--no-drivers",
        dest="drivers",
        action="store_false",
        help="skip hardware driver detection and installation",
    )
    _set_install_epilog(install_parser)

    # Create parser for update opts
    update_parser = command_parser.add_parser("update", help="update the Olvex dotfiles")
    update_parser.set_defaults(cls=update.Command)
    update_parser.add_argument("--aur-helper", choices=AUR_HELPERS, help="the AUR helper to use")
    update_parser.add_argument("--noconfirm", action="store_true", help="use defaults for all prompts")

    return parser, parser.parse_args()


def _set_install_epilog(install_parser: argparse.ArgumentParser) -> None:
    """Add components if using install subcommand"""

    if len(sys.argv) > 1 and sys.argv[1] == "install":
        manifest = _load_install_manifest()
        if manifest is not None and manifest.components:
            install_parser.epilog = _components_epilog(manifest)


def _load_install_manifest() -> Manifest | None:
    source = DotsSource()
    try:
        source.ensure()
        return source.manifest_at(source.remote_ref)
    except Exception as e:
        warn(f"failed to load manifest from dots repo ({e})\n", prefix=False)
        return None


def _components_epilog(manifest: Manifest) -> str:
    def e(*v: int) -> str:
        return f"\033[{';'.join(str(c) for c in v)}m"

    def b(c: int) -> str:
        return e(1, c)

    reset = e(0)

    width = max(len(name) for name in manifest.components)
    lines = [f"{b(34)}available components (for --enable-components / --disable-components):{reset}"]
    for name, comp in manifest.components.items():
        lines.append(f"  {b(32)}{name:<{width}}{reset}\t{'(default)' if comp.default else '(off)'}")
    return "\n".join(lines)
