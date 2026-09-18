"""Build the playground's opcode help from Luau's Bytecode.h comments.

Usage: python scripts/generate_opcode_help.py path/to/luau
"""

import json
import re
import subprocess
import sys
from pathlib import Path


def main() -> None:
    luau = Path(sys.argv[1]).resolve()
    header = luau / "Common/include/Luau/Bytecode.h"
    source = header.read_text(encoding="utf-8").splitlines()
    start = next(i for i, line in enumerate(source) if line.strip() == "enum LuauOpcode")
    end = next(i for i in range(start, len(source)) if "LOP__COUNT" in source[i])

    opcodes = {}
    comments = []
    active_comments = []
    after_opcode = False
    for number in range(start + 1, end):
        line = source[number].strip()
        if line.startswith("//"):
            if after_opcode:
                comments = []
                after_opcode = False
            comments.append(line[2:].strip())
            continue
        match = re.match(r"LOP_([A-Z0-9_]+),", line)
        if not match:
            continue
        if comments:
            active_comments = comments
            comments = []
        if not active_comments:
            raise ValueError(f"Missing opcode comments for {match[1]}")
        description = active_comments[0]
        description = re.sub(r"^[A-Z0-9_, ]+:\s*", "", description)
        details = [part for part in active_comments[1:] if part]
        opcodes[match[1]] = {
            "description": description,
            "details": details,
            "line": number + 1,
        }
        after_opcode = True

    revision = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=luau, text=True
    ).strip()
    payload = {
        "source": f"https://github.com/luau-lang/luau/blob/{revision}/Common/include/Luau/Bytecode.h",
        "license": (luau / "LICENSE.txt").read_text(encoding="utf-8"),
        "opcodes": opcodes,
    }
    output = Path(__file__).resolve().parents[1] / "docs/playground/opcode-help.json"
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(opcodes)} opcode descriptions to {output}")


if __name__ == "__main__":
    main()
