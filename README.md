# `nix-mk-shell-bin`

`nix develop`, but at build time.

> **Note**
> See NixOS/nixpkgs#206915.

## what

This is a nix expression that replicates the [transformation `nix develop` does on derivations](https://github.com/NixOS/nix/blob/4248174e7165f48f92416d13b862e3ef8192a34b/src/nix/develop.cc#L464-L569), ultimately yielding a script that, when run, drops you into a `nix develop`-like shell.

## but why?

Mostly for [`nix-bundle`](https://github.com/matthewbauer/nix-bundle).

I wanted to be able to package a `mkShell` derivation as a self-contained executable; you can't do this directly since `mkShell` doesn't actually produce a binary that you can run (`mkShell` [used to](https://github.com/NixOS/nixpkgs/pull/153194) actually produce derivations that you [couldn't](https://github.com/NixOS/nixpkgs/blob/c524608dca14c8716eaefa88d2aa8c757af48daa/pkgs/build-support/mkshell/default.nix#L44-L49) even build normally).

`mkShell` instead relies on `nix develop` (or `nix-shell`) to extract information from the derivation and construct an environment from it. `mkShellBin` does more or less the same steps to construct this environment but does so as part of building its derivation.

## do you have an example?

Sure. This repo is packaged as a [flake](https://nixos.wiki/wiki/Flakes), so:

```nix
{
  # Add to your flake's inputs:
  inputs.msb = github:rrbutani/nix-mk-shell-bin;

  # Use `mkShellBin`, exposed under `lib`:
  outputs = { msb, ... }: let
    mkShellBin = msb.lib.mkShellBin;
  in {
    # ...
  };
}
```

`mkShellBin` takes:
```nix
{ drv
, nixpkgs
, bashPrompt ? null
, bashPromptPrefix ? null
, bashPromptSuffix ? null
}
```

Here's an example flake that you can run:
<!-- EXAMPLE: flake.nix -->
```nix
{
  inputs = {
    msb.url = github:rrbutani/nix-mk-shell-bin;
    nixpkgs.url = github:nixOS/nixpkgs/22.11;
    flu.url = github:numtide/flake-utils;
  };

  outputs = { msb, nixpkgs, flu, ... }: with msb.lib; with flu.lib; eachDefaultSystem(system: let
    np = nixpkgs.legacyPackages.${system};

    # Like `nix-shell`, this will build the dependencies of `pkg` but not
    # `pkg` itself.
    pkg = np.hello;
    pkgShellBin = mkShellBin { drv = pkg; nixpkgs = np; };

    # Here, `shellBin` *will* build `pkg`. This is like `nix develop`.
    shell = np.mkShell { name = "example"; nativeBuildInputs = [pkg]; };
    shellBin = msb.lib.mkShellBin { drv = shell; nixpkgs = np; bashPrompt = "[hello]$ "; };

  in {
    # You can run `nix bundle` and get a self-contained executable that,
    # when run, drops you into a shell containing `pkg`.
    packages.default = shellBin;
    packages.pkgShellBin = pkgShellBin;

    # You can run the derivations `mkShellBin` produces:
    apps.default = { type = "app"; program = "${shellBin}/bin/${shellBin.name}"; };

    # The above is more or less equivalent to:
    devShells.default = shell;
  });
}
```
<!-- EXAMPLE: flake.nix -->

<!-- EXAMPLE: flake.lock -->
<!--
{
  "nodes": {
    "flu": {
      "locked": {
        "lastModified": 1667395993,
        "narHash": "sha256-nuEHfE/LcWyuSWnS8t12N1wc105Qtau+/OdUAjtQ0rA=",
        "owner": "numtide",
        "repo": "flake-utils",
        "rev": "5aed5285a952e0b949eb3ba02c12fa4fcfef535f",
        "type": "github"
      },
      "original": {
        "owner": "numtide",
        "repo": "flake-utils",
        "type": "github"
      }
    },
    "msb": {
      "locked": {
        "lastModified": 1662002159,
        "narHash": "sha256-wNRqslo43TVheciW/auWXv1gGT97N+B5iirdhVthxfg=",
        "owner": "rrbutani",
        "repo": "nix-mk-shell-bin",
        "rev": "b671559e49338199c3d5ac434ea4b1f61f53df0f",
        "type": "github"
      },
      "original": {
        "owner": "rrbutani",
        "repo": "nix-mk-shell-bin",
        "type": "github"
      }
    },
    "nixpkgs": {
      "locked": {
        "lastModified": 1669833724,
        "narHash": "sha256-/HEZNyGbnQecrgJnfE8d0WC5c1xuPSD2LUpB6YXlg4c=",
        "owner": "nixOS",
        "repo": "nixpkgs",
        "rev": "4d2b37a84fad1091b9de401eb450aae66f1a741e",
        "type": "github"
      },
      "original": {
        "owner": "nixOS",
        "ref": "22.11",
        "repo": "nixpkgs",
        "type": "github"
      }
    },
    "root": {
      "inputs": {
        "flu": "flu",
        "msb": "msb",
        "nixpkgs": "nixpkgs"
      }
    }
  },
  "root": "root",
  "version": 7
}
-->
<!-- EXAMPLE: flake.lock -->

## anything else?

This repo makes use of [source code](get-env.sh) from the [`nix` repo](https://github.com/NixOS/nix) and, like the `nix` repo, is licensed under the LGPLv2.
