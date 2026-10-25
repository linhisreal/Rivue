"""Bundles the runtime, prelude, and test files into one script for the Luau CLI."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RUNTIME = os.path.join(ROOT, "src", "shared", "Rivue", "runtime")
EXAMPLES = os.path.join(ROOT, "examples", "components")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def main(test_files):
    out = [read(os.path.join(ROOT, "tests", "offline", "prelude.luau"))]
    for name in sorted(os.listdir(RUNTIME)):
        if name.endswith(".luau"):
            module = name[: -len(".luau")]
            out.append(f'__defineModule(runtimeFolder, "{module}", function(script)\n{read(os.path.join(RUNTIME, name))}\nend)')
    # Example components live in ReplicatedStorage.Examples
    out.append('local examplesFolder = makeFolder("Examples", ReplicatedStorage)\nReplicatedStorage._children.Examples = examplesFolder')
    for name in sorted(os.listdir(EXAMPLES)):
        if name.endswith(".luau"):
            module = name[: -len(".luau")]
            out.append(f'__defineModule(examplesFolder, "{module}", function(script)\n{read(os.path.join(EXAMPLES, name))}\nend)')
    wrapper = read(os.path.join(ROOT, "src", "shared", "Rivue", "Rivue.luau"))
    out.append(f'__defineModule(nil, "Rivue", function(script)\n{wrapper}\nend)')
    for path in test_files:
        out.append(f'__runTest("{os.path.basename(path)}", function(script)\n{read(path)}\nend)')
    out.append("__finish()")
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1:])
