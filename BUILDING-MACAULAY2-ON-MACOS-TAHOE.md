# Building Macaulay2 on macOS Tahoe

This is a from-scratch build recipe for Macaulay2 on macOS Tahoe, written from
a successful local build on:

- macOS 26.3.1 Tahoe, arm64
- Apple Clang 17.0.0
- Homebrew 5.1.11 under `/opt/homebrew`
- Macaulay2 branch `Group1`, version `1.26.05`

The commands below follow the Macaulay2 wiki's macOS and CMake build guidance,
with one Tahoe/Homebrew adjustment: use `brew deps --full-name` so the
Macaulay2 `factory` formula is not confused with the unrelated Homebrew cask.

Sources:

- [Building M2 from source on macOS](https://github.com/Macaulay2/M2/wiki/Building-M2-from-source-on-macOS)
- [Building M2 from source using CMake](https://github.com/Macaulay2/M2/wiki/Building-M2-from-source-using-CMake)
- [FAQ: CMake Build Problems](https://github.com/Macaulay2/M2/wiki/FAQ:-CMake-Build-Problems)
- [Building M2 from source using Autotools](https://github.com/Macaulay2/M2/wiki/Building-M2-from-source-using-Autotools)

## 1. Install macOS command line tools and Homebrew

If this is a new Mac, start with Apple's command line tools:

```bash
xcode-select --install
```

Install Homebrew if it is not already installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Check the toolchain:

```bash
sw_vers
uname -m
clang --version
brew --version
```

## 2. Clone the Macaulay2 repository

From the directory where you keep source checkouts:

```bash
git clone https://github.com/Macaulay2/M2.git
cd M2
```

The repository root contains this README layout:

```text
README.md
M2/
```

Most build commands run from the nested source/build tree under `M2/`.

## 3. Install Homebrew dependencies

Tap the Macaulay2 Homebrew formulas:

```bash
brew tap macaulay2/tap
```

Install the accelerator and build/runtime dependencies:

```bash
brew install ccache
brew install --formula $(brew deps --1 --include-build --full-name macaulay2/tap/M2)
```

The `--full-name` flag matters on Tahoe/Homebrew because the dependency list
contains `macaulay2/tap/factory`; without full names, Homebrew may also treat
`factory` as a cask.

Confirm the key tools:

```bash
command -v cmake
command -v ninja
command -v ccache
command -v gfortran
cmake --version
ninja --version
```

On the Tahoe machine used for this build, these were the concrete pieces that
had to be added or verified:

```bash
brew list --versions ccache bison eigen@3 ninja node
brew list --versions macaulay2/tap/factory
```

Notes on those pieces:

- `ccache` is optional but recommended by the wiki; CMake detected it and used
  `/opt/homebrew/bin/ccache`.
- `ninja` is required for the `-GNinja` generator used below.
- `eigen@3` and `bison` were pulled in by the Macaulay2 dependency formula.
- Homebrew's `bison` is keg-only. The successful local build still worked with
  `/usr/bin/bison`; if your configure step needs the Homebrew one explicitly,
  run `export PATH="$(brew --prefix bison)/bin:$PATH"` before CMake.
- `node` is used during the editor syntax asset generation step; Homebrew may
  install or upgrade it as part of the Macaulay2 dependency set.
- `macaulay2/tap/factory` is the required formula. If you accidentally install
  the unrelated `factory` cask, remove it with `brew uninstall --cask factory`.

## 4. Prepare a clean build directory

From the repository root:

```bash
mkdir -p M2/BUILD/build
find M2/BUILD/build -mindepth 1 -maxdepth 1 \
  ! -name README \
  ! -name .gitignore \
  -exec rm -rf {} +
```

The `README` and `.gitignore` files in `M2/BUILD/build` are tracked
placeholders, so the command above preserves them.

This cleanup also removes stale Autotools leftovers such as `config.args` and
`config.log`. If you are reusing an existing build directory instead, remove at
least any old CMake cache before reconfiguring:

```bash
rm -f M2/BUILD/build/CMakeCache.txt
rm -rf M2/BUILD/build/CMakeFiles
```

## 5. Build the CMake prefix path from Homebrew formulas

This is a robust version of the macOS wiki's prefix-path command. It asks
Homebrew for each dependency's real prefix instead of constructing paths by
string substitution.

```bash
cd M2/BUILD/build

paths="$(
  brew deps --1 --include-optional --full-name macaulay2/tap/M2 |
    while read -r formula; do
      brew --prefix "$formula"
    done |
    paste -sd ';' -
)"

printf '%s\n' "$paths" > homebrew-cmake-prefix-path.txt
```

The generated `homebrew-cmake-prefix-path.txt` file is optional, but useful
when debugging what CMake saw.

## 6. Configure with CMake and Ninja

Still in `M2/BUILD/build`:

```bash
cmake -GNinja -S ../.. -B . \
  -DBUILD_NATIVE=OFF \
  -DCMAKE_PREFIX_PATH="$paths" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr
```

Notes:

- `-S ../..` points from `M2/BUILD/build` back to the nested source directory
  `M2/`.
- `BUILD_NATIVE=OFF` follows the macOS wiki and avoids baking in CPU-specific
  instructions.
- `CMAKE_INSTALL_PREFIX=/usr` matches the wiki. The normal local build does not
  install into `/usr`; it builds a runnable tree under `M2/BUILD/build/usr-dist`.
- CMake may initialize submodules during configure. That is expected.

If you want to make the submodule step explicit before configuring, run:

```bash
git submodule update --init --recursive
```

If CMake has trouble finding SDK headers or libraries, the CMake FAQ suggests
rerunning configure with the active SDK:

```bash
cmake -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" .
```

## 7. Compile

Run the default Ninja target:

```bash
ninja
```

On the successful Tahoe build that produced this guide, Ninja ran 750 build
steps and produced:

```text
M2/BUILD/build/M2
M2/BUILD/build/usr-dist/arm64-Darwin-macOS-26.3.1/bin/M2
M2/BUILD/build/usr-dist/arm64-Darwin-macOS-26.3.1/bin/M2-binary
```

The build emitted ordinary warnings, including macOS 26 SDK deprecation warnings
from libxml and a nonfatal package warning:

```text
warning: R cannot be found; ending
```

That warning affects the optional `RInterface` package metadata, not the core
build.

If you need `RInterface`, install R before rebuilding that package:

```bash
brew install --cask r
```

## 8. Smoke test the build

From `M2/BUILD/build`:

```bash
./M2 --version
```

Expected result for this checkout:

```text
1.26.05
```

Run a small algebra computation:

```bash
./M2 --silent --stop --no-readline \
  -e 'R = QQ[x,y]; I = ideal(x^2, y^2); print betti res I; exit 0'
```

Expected output:

```text
       0 1 2
total: 1 2 1
    0: 1 . .
    1: . 2 .
    2: . . 1
```

Run a small CTest subset:

```bash
ctest -R 'unit-tests:(Arena.NoOp|BitTriangle.NoOp|PrimeField)' -j4 --output-on-failure
```

The successful local run passed 12 of 12 tests.

## 9. Running Macaulay2 from the build tree

Use the generated launcher:

```bash
cd M2/BUILD/build
./M2
```

For convenience in a shell session:

```bash
export PATH="$PWD:$PATH"
M2 --version
```

## 10. Optional install or staging

I did not install into `/usr` during the local build. If you want a staged
install instead of touching system paths, use `DESTDIR`:

```bash
cd M2/BUILD/build
DESTDIR="$PWD/stage" cmake --install .
```

If you truly want to install to the configured prefix, run:

```bash
cd M2/BUILD/build
sudo cmake --install .
```

## 11. Autotools fallback

CMake/Ninja is the path used here. If you need the Autotools path from the
wiki, install its tools and use GNU Make (`gmake`) on macOS:

```bash
brew install ccache ctags gnu-tar make wget yasm

cd M2
gmake get-libtool
gmake -f Makefile

cd BUILD/build
CC=/usr/bin/gcc CXX=/usr/bin/g++ ../../configure \
  --enable-download \
  --enable-build-libraries="readline"

gmake IgnoreExampleErrors=false
```

For current Homebrew GCC on this Tahoe machine, `gfortran` is available as:

```bash
/opt/homebrew/bin/gfortran
/opt/homebrew/bin/gfortran-15
```

If Autotools cannot find Python, readline, libomp, or factory, add the flags
shown in the Autotools wiki's macOS section and update the Python/GFortran
version numbers for your machine.

## 12. Cleanup notes

Build outputs live under `M2/BUILD/build` and are not meant to be committed.
The CMake build may also generate `M2/Macaulay2/editors/emacs/M2-symbols.el.gz`
inside the Emacs submodule. Treat it as a generated artifact unless you are
intentionally updating editor support files.

After a successful local build, `git status --short` can show untracked build
products like these:

```text
?? M2/BUILD/build/.ninja_deps
?? M2/BUILD/build/.ninja_log
?? M2/BUILD/build/CMakeCache.txt
?? M2/BUILD/build/CMakeFiles/
?? M2/BUILD/build/M2
?? M2/BUILD/build/build.ninja
?? M2/BUILD/build/usr-dist/
 ? M2/Macaulay2/editors/emacs
```

The `?` on the Emacs submodule was caused here by the generated
`M2-symbols.el.gz` file.

To remove the local CMake build:

```bash
mkdir -p M2/BUILD/build
find M2/BUILD/build -mindepth 1 -maxdepth 1 \
  ! -name README \
  ! -name .gitignore \
  -exec rm -rf {} +
```

## 13. Notes on web tutorial gaps and Tahoe changes

The Macaulay2 wiki pages were the right starting point, but a few details had
to be adjusted for this macOS Tahoe build:

- The macOS wiki command `brew install $(brew deps ...)` can mis-handle
  `factory` on current Homebrew, because there is both a Macaulay2 formula and
  an unrelated cask. This guide uses `--full-name` and `--formula` so
  `macaulay2/tap/factory` is selected.
- The wiki's CMake prefix-path construction assumes every dependency is under
  `$HOMEBREW_PREFIX/opt/<name>`. This guide asks `brew --prefix` for each
  formula, which is more reliable for tapped formulas and versioned formulas
  such as `python@3.14` and `eigen@3`.
- The web instructions mention `ccache`, but the practical CMake/Ninja path
  also needed `ninja`, `bison`, `eigen@3`, and `node` present or installed by
  the Homebrew dependency pass.
- Homebrew `bison` is keg-only on macOS. The successful Tahoe build used the
  system `/usr/bin/bison`, but the guide documents how to put Homebrew's bison
  first in `PATH` if CMake or Autotools needs it.
- The Autotools page shows example versioned paths for Python 3.13 and
  `gfortran-14`. On this Tahoe machine, CMake found Homebrew `python@3.14`,
  and Homebrew GCC installed `gfortran-15`; treat those web values as examples,
  not constants.
- The wiki does not call out stale Autotools files in `M2/BUILD/build`; this
  checkout already had `config.args` and `config.log`, so the cleanup step here
  preserves tracked placeholders while removing stale generated files.
- CMake initialized several git submodules during configure. That is normal,
  but the guide includes an explicit `git submodule update --init --recursive`
  command for users who prefer to make that step visible.
- The web tutorials do not mention the optional `RInterface` warning. On this
  machine, the build printed `warning: R cannot be found; ending`; the core
  build still completed, and this guide notes `brew install --cask r` for users
  who need that package.
- The generated Emacs file `M2/Macaulay2/editors/emacs/M2-symbols.el.gz` can
  make the Emacs submodule appear dirty in `git status`; this guide records it
  as a generated artifact.
