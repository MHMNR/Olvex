import subprocess
from argparse import Namespace

from olvex.utils.paths import c_cache_dir
from olvex.utils.qs_shell import qs_check_output, qs_popen, qs_prefix, qs_run


class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        if self.args.show:
            self.print_ipc()
        elif self.args.log:
            self.print_log()
        elif self.args.kill:
            self.shell("kill")
        elif self.args.message:
            self.message(*self.args.message)
        else:
            # Start shell against the resolved Olvex config (project -p preferred)
            args = [*qs_prefix(), "-n"]
            if self.args.log_rules:
                args.extend(["--log-rules", self.args.log_rules])
            if self.args.daemon:
                args.append("-d")
                subprocess.run(args)
            else:
                shell = subprocess.Popen(args, stdout=subprocess.PIPE, universal_newlines=True)
                if shell.stdout:
                    for line in shell.stdout:
                        if self.filter_log(line):
                            print(line, end="")

    def shell(self, *args: str) -> str:
        return qs_check_output(list(args))

    def filter_log(self, line: str) -> bool:
        return f"Cannot open: file://{c_cache_dir}/imagecache/" not in line

    def print_ipc(self) -> None:
        print(self.shell("ipc", "show"), end="")

    def print_log(self) -> None:
        if self.args.log_rules:
            log = self.shell("log", "-r", self.args.log_rules)
        else:
            log = self.shell("log")
        for line in log.splitlines():
            if self.filter_log(line):
                print(line)

    def message(self, *args: list[str]) -> None:
        print(self.shell("ipc", "call", *args), end="")
