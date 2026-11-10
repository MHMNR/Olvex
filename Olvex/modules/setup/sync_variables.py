#!/usr/bin/env python3
import sys
import re
import os
import subprocess

def update_file(path, terminal, browser, file_explorer):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if terminal:
        content = re.sub(r'(\bterminal\s*=\s*)"[^"]*"', rf'\g<1>"{terminal}"', content)
    if browser:
        content = re.sub(r'(\bbrowser\s*=\s*)"[^"]*"', rf'\g<1>"{browser}"', content)
    if file_explorer:
        content = re.sub(r'(\bfileExplorer\s*=\s*)"[^"]*"', rf'\g<1>"{file_explorer}"', content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def main():
    terminal = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else None
    browser = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
    file_explorer = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None

    home = os.path.expanduser("~")
    user_hypr = os.path.join(home, ".config", "hypr", "variables.lua")
    github_hypr = os.path.join(home, "Projects", "QS-Config", "Github", ".config", "hypr", "variables.lua")

    update_file(user_hypr, terminal, browser, file_explorer)
    update_file(github_hypr, terminal, browser, file_explorer)

    try:
        subprocess.run(["hyprctl", "reload"], check=False)
    except Exception:
        pass

if __name__ == "__main__":
    main()

