import json
from argparse import Namespace

from olvex.utils.wallpaper import get_colours_for_wall, get_wallpaper, set_random, set_wallpaper


class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        force_mode = getattr(self.args, "scheme_mode", None)
        if self.args.print:
            print(json.dumps(get_colours_for_wall(self.args.print, self.args.no_smart, force_mode)))
        elif self.args.file:
            set_wallpaper(self.args.file, self.args.no_smart, force_mode)
        elif self.args.random:
            set_random(self.args)
        else:
            print(get_wallpaper() or "No wallpaper set")
