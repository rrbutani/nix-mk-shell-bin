#!/usr/bin/env python3

# Based on `nix/develop.cc`; last updated to:
# https://github.com/NixOS/nix/blob/fa4733fce5e473901ccb5dfd08593c861a4e1f0e/src/nix/develop.cc

import json
import os
from typing import List, Tuple

# https://github.com/NixOS/nix/blob/27be54ca533933db8c3e0cde4b213abf10dd5237/src/nix/develop.cc#L241-L259
IGNORE = [
    "BASHOPTS",
    "HOME",
    "NIX_BUILD_TOP",
    "NIX_ENFORCE_PURITY",
    "NIX_LOG_FD",
    "NIX_REMOTE",
    "PPID",
    "SHELL",
    "SHELLOPTS",
    "SSL_CERT_FILE",
    "TEMP",
    "TEMPDIR",
    "TERM",
    "TMP",
    "TMPDIR",
    "TZ",
    "UID",
]

# https://github.com/NixOS/nix/blob/155c57c17131770a33dbd86055684d3605a0d505/src/nix/develop.cc#L282
SAVED = [
    "PATH",          # for commands
    "XDG_DATA_DIRS", # for loadable completion
]

# https://github.com/NixOS/nix/blob/1e55ee2961eabd6016dfef1793996ded97c9054c/src/libutil/util.cc#L1423
def shell_escape(inp) -> str:
    s = "\'"
    for i in inp:
        if i == '\'': s += "'\\''"
        else: s += i
    s += '\''
    return s

# https://github.com/NixOS/nix/blob/155c57c17131770a33dbd86055684d3605a0d505/src/nix/develop.cc#L54
# https://github.com/NixOS/nix/blob/155c57c17131770a33dbd86055684d3605a0d505/src/nix/develop.cc#L111
def process(env):
    for name, info in env["variables"].items():
        if name in IGNORE: continue
        ty = info["type"]
        if ty == "unknown": continue
        val = info["value"]

        if ty == "var" or ty == "exported":
            yield f"{name}={shell_escape(val)}\n"
            if ty == "exported":
                yield f"export {name}\n"

        if ty == "array":
            arr = " ".join(shell_escape(v) for v in val)
            yield f"declare -a {name}=({arr})\n"

        if ty == "associative":
            arr = " ".join(
                f"[{shell_escape(k)}]={shell_escape(v)}"
                for k, v in val.items()
            )
            yield f"declare -A {name}=({arr})\n"

    for name, val in env["bashFunctions"].items():
        yield f"{name}()\n{{\n{val}}}\n"

def get_keys(json_item):
    ty, val = json_item["type"], json_item["value"]
    if ty == "var" or ty == "exported":
        return val.split(" ")
    elif ty == "array":
        return val
    elif ty == "associative":
        return val.keys()

# https://github.com/NixOS/nix/blob/155c57c17131770a33dbd86055684d3605a0d505/src/nix/develop.cc#L274
def make_rc_script(env):
    yield "unset shellHook\n"

    for v in SAVED:
        yield f"{v}=\"${{{v}:-}}\"\n"
        yield f"nix_saved_{v}=\"${v}\"\n"

    yield from process(env)

    for v in SAVED:
        yield f"{v}=\"${v}:$nix_saved_{v}\"\n"

    yield "export NIX_BUILD_TOP=\"$(mktemp -d -t nix-shell.XXXXXX)\"\n"
    for i in ["TMP", "TMPDIR", "TEMP", "TEMPDIR"]:
        yield f"export {i}=\"$NIX_BUILD_TOP\"\n"

    yield "eval \"$shellHook\"\n"

# https://github.com/NixOS/nix/blob/1e55ee2961eabd6016dfef1793996ded97c9054c/src/libutil/util.cc#L1363
def rewrite(s: str, rewrites: List[Tuple[str, str]]) -> str:
    for orig, rep in rewrites:
        s.replace(orig, rep)

    return s

def make_script(env):
    script = "".join(make_rc_script(env))

    outputs = env["variables"]["outputs"]
    outputsDir = "./outputs"
    rewrites = []
    for output in get_keys(outputs):
        rewrites.append((env["variables"][output]["value"], f"{outputsDir}/{output}"))

    rewrite(script, rewrites)

    script = "[ -n \"$PS1\" ] && [ -e ~/.bashrc ] && source ~/.bashrc;\n" + script
    if_env_var = lambda v, f: f(shell_escape(os.environ[v])) if v in os.environ else ""
    script += if_env_var("bashPrompt", lambda p: f"[ -n \"$PS1\" ] && PS1={p};\n")
    script += if_env_var("bashPromptPrefix", lambda p: f"[ -n \"$PS1\" ] && PS1=%{p}\"$PS1\";\n")
    script += if_env_var("bashPromptSuffix", lambda p: f"[ -n \"$PS1\" ] && PS1+={p};\n")

    return script

env = json.load(open(os.environ["envInp"]))
out = make_script(env)

print(out)
