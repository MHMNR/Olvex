from olvex.parser import parse_args
from olvex.utils.io import log
from olvex.utils.version import print_version


def main() -> None:
    try:
        parser, args = parse_args()
        if args.version:
            print_version()
        elif "cls" in args:
            args.cls(args).run()
        else:
            parser.print_help()
    except KeyboardInterrupt:
        log("Exiting...")
