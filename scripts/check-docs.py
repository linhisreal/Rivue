"""Checks the docs: relative links and #anchors resolve, and every API example compiles and runs.

Usage: python3 scripts/check-docs.py   (set LUAU to the luau binary if it isn't on PATH)

Examples are the ```lua blocks in docs/api/*.md, except the ones under a **Type**, **Props** or
**Expects** heading (those are signatures). Each one runs in the offline test harness with
`Rivue`, `h` and `Players` defined, the same as the docs assume.
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = os.environ.get("LUAU", "luau")

DOC_FILES = [os.path.join(ROOT, "README.md")]
for folder in ("docs", os.path.join("docs", "api"), "examples"):
    path = os.path.join(ROOT, folder)
    DOC_FILES += [os.path.join(path, f) for f in sorted(os.listdir(path)) if f.endswith(".md")]


def slug(heading):
    """GitHub's anchor for a heading."""
    text = heading.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def anchors_of(path):
    found = {}
    result = set()
    in_code = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.lstrip().startswith("```"):
                in_code = not in_code
            if in_code:
                continue
            match = re.match(r"^#{1,6}\s+(.*)", line)
            if match:
                base = slug(match.group(1))
                count = found.get(base, 0)
                result.add(base if count == 0 else f"{base}-{count}")
                found[base] = count + 1
    return result


def check_links():
    errors = []
    cache = {}
    for path in DOC_FILES:
        text = open(path, encoding="utf-8").read()
        text = re.sub(r"```.*?```", "", text, flags=re.S)
        for target in re.findall(r"\]\(([^)\s]+)\)", text):
            if re.match(r"^[a-z]+://", target) or target.startswith("mailto:"):
                continue
            file_part, _, anchor = target.partition("#")
            dest = os.path.normpath(os.path.join(os.path.dirname(path), file_part)) if file_part else path
            rel = os.path.relpath(path, ROOT)
            if not os.path.exists(dest):
                errors.append(f"{rel}: broken link {target}")
                continue
            if anchor and dest.endswith(".md"):
                if dest not in cache:
                    cache[dest] = anchors_of(dest)
                if anchor not in cache[dest]:
                    errors.append(f"{rel}: missing anchor {target}")
    return errors


def examples():
    out = []
    api = os.path.join(ROOT, "docs", "api")
    for name in sorted(os.listdir(api)):
        if not name.endswith(".md"):
            continue
        lines = open(os.path.join(api, name), encoding="utf-8").read().split("\n")
        section = None
        seen_heading = False
        server = False
        i = 0
        while i < len(lines):
            line = lines[i]
            if line.startswith("## "):
                seen_heading = True
            label = re.match(r"^\s*- \*\*(\w+)", line)
            if label:
                section = label.group(1)
            if line.strip() == "<!-- server -->":
                server = True
            if line.lstrip().startswith("```lua"):
                indent = len(line) - len(line.lstrip())
                body = []
                start = i + 1
                i += 1
                while not lines[i].lstrip().startswith("```"):
                    body.append(lines[i][indent:])
                    i += 1
                # Blocks before the first entry are the page's "examples assume" preamble
                if seen_heading and section not in ("Type", "Props", "Expects"):
                    out.append((f"{name}:{start}", "\n".join(body), server))
                server = False
            i += 1
    return out


PREAMBLE = """local Rivue = require(game:GetService("ReplicatedStorage"):WaitForChild("Rivue"))
local h = Rivue.h
local Players = game:GetService("Players")
"""


def check_examples():
    errors = []
    blocks = examples()
    with tempfile.TemporaryDirectory() as tmp:
        test = os.path.join(tmp, "DocExamples.test.luau")
        with open(test, "w", encoding="utf-8") as f:
            # One closure per example, so locals don't pile up in a single function
            f.write("local examples = {}\n")
            for label, code, server in blocks:
                flag = "true" if server else "false"
                f.write(f'table.insert(examples, {{ "{label}", function()\n{PREAMBLE}\n{code}\nend, {flag} }})\n')
            f.write("return function()\n")
            f.write('\tlocal RunService = game:GetService("RunService")\n')
            f.write("\tfor _, example in examples do\n")
            # Examples marked <!-- server --> run with RunService reporting the server
            f.write("\t\tif example[3] then\n")
            f.write("\t\t\tRunService.IsServer = function() return true end\n")
            f.write("\t\t\tRunService.IsClient = function() return false end\n")
            f.write("\t\tend\n")
            f.write("\t\tlocal ok, err = pcall(example[2])\n")
            f.write("\t\tRunService.IsServer = function() return false end\n")
            f.write("\t\tRunService.IsClient = function() return true end\n")
            f.write('\t\tif not ok then print("DOCFAIL " .. example[1] .. ": " .. tostring(err)) end\n')
            f.write("\t\ttask.wait(0.05)\n")
            f.write("\tend\n")
            f.write("end\n")
        bundle = subprocess.run(
            [sys.executable, os.path.join(ROOT, "tests", "offline", "bundle.py"), test],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        script = os.path.join(tmp, "bundle.luau")
        with open(script, "w", encoding="utf-8") as f:
            f.write(bundle)
        run = subprocess.run([LUAU, script], capture_output=True, text=True, timeout=300)
        output = run.stdout + run.stderr
        errors += [line for line in output.splitlines() if line.startswith("DOCFAIL")]
        errors += [line for line in output.splitlines() if "THREAD ERROR" in line]
        if "RESULT: 1 passed" not in output:
            errors.append("examples didn't run to completion:\n" + "\n".join(output.splitlines()[-8:]))
    return errors, len(blocks)


def main():
    errors = check_links()
    example_errors, count = check_examples()
    errors += example_errors
    for error in errors:
        print(error)
    print(f"{count} examples, {len(DOC_FILES)} docs checked, {len(errors)} problems")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
