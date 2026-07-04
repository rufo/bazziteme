#!/bin/bash
# Build the gnome-rounded-blur helper library for blur-my-shell and stage its
# artifacts under /blur-out for the final image stage to COPY --from in.
# Runs in a throwaway builder stage built FROM the same base as the runtime image,
# so the lib is compiled against the exact mutter ABI shipped in the final image.
# See https://github.com/aunetx/blur-my-shell/blob/master/scripts/GUIDE.md
#
# Defensive: if the library is already present in the base image (e.g. added by
# upstream), the build is skipped; and because this is purely cosmetic, any
# failure during the build produces an empty /blur-out so the final image still
# builds without the helper - blur_my_shell will simply run without rounded
# corners until the next base update.
set -uo pipefail

blur_lib_sentinel=/usr/lib64/libblur-effect-1.0.so
if [[ -e "$blur_lib_sentinel" ]]; then
    echo "blur-build: $blur_lib_sentinel already present in base image; skipping build"
    mkdir -p /blur-out
    exit 0
fi

# set -e from here on, but trap failures into an empty /blur-out so the runtime
# stage's COPY --from still succeeds (no rounding -> cosmetic degradation only).
trap 'echo "blur-build: build failed (cosmetic feature); leaving /blur-out empty"; mkdir -p /blur-out; exit 0' ERR
set -e

BLUR_BUILD_DEPS=(git meson glib2-devel mutter-devel gobject-introspection gcc)

# The bazzite base image excludes mesa-* and mutter* via a generated dnf override
# (/etc/dnf/repos.override.d/99-config_manager.repo) to lock its multimedia stack;
# mutter-devel needs mesa-libgbm-devel (already present as the matching runtime),
# so move the override aside for this install, then restore it.
blur_override=/etc/dnf/repos.override.d/99-config_manager.repo
mv "$blur_override" "$blur_override.disabled"
dnf5 -y install "${BLUR_BUILD_DEPS[@]}"
mv "$blur_override.disabled" "$blur_override"

# The bazzite base image ships ccache, which meson auto-detects as the C compiler
# wrapper (/usr/sbin/ccache cc). Inside the build container's tmpfs /tmp, ccache
# fails with "File exists" while initializing its cache; disable the wrapper so
# it passes through to the real compiler.
export CCACHE_DISABLE=1

blur_build_dir=/tmp/gnome-rounded-blur
rm -rf "$blur_build_dir"
git clone https://github.com/kancko/gnome-rounded-blur "$blur_build_dir"

# Patch meson.build to match the installed mutter, mirroring the upstream
# rounded_blur_build.sh prep_stage logic.
MUTTER_SYS_VER=$(mutter --version | grep -o -P '(?<=mutter ).*' | sed -e 's/"//g' -e "s/'//g" -e 's/\..*//g')
HARDCODE_MUTTER_SYS_VER=$(grep -o -P '(?<=mutter_req = ).*' "$blur_build_dir/meson.build" \
    | sed -e 's/"//g' -e "s/'//g" -e 's/\..*//g' -e 's/>//g' -e 's/=//g' -e 's/ //g')
MUTTER_API_REPO_VER=$(grep -o -P '(?<=mutter_api_version = ).*' "$blur_build_dir/meson.build" \
    | sed -e 's/"//g' -e "s/'//g" -e 's/ //g')
if [[ "$MUTTER_SYS_VER" -ge "$HARDCODE_MUTTER_SYS_VER" ]]; then
    DIFF_VALUE=$(( MUTTER_SYS_VER - HARDCODE_MUTTER_SYS_VER ))
    DIFF_VALUE_2=$(( MUTTER_API_REPO_VER + DIFF_VALUE ))
    sed -i -e '0,/'"mutter_api_version = ""$MUTTER_API_REPO_VER"'/{s/'"$MUTTER_API_REPO_VER"'/'"$DIFF_VALUE_2"'/g}' \
        "$blur_build_dir/meson.build"
else
    DIFF_VALUE=$(( HARDCODE_MUTTER_SYS_VER - MUTTER_SYS_VER ))
    DIFF_VALUE_2=$(( MUTTER_API_REPO_VER - DIFF_VALUE ))
    sed -i -e '0,/'"mutter_req = ""$HARDCODE_MUTTER_SYS_VER"'/{s/'"$HARDCODE_MUTTER_SYS_VER"'/'"$MUTTER_SYS_VER"'/g}' \
        "$blur_build_dir/meson.build"
    sed -i -e '0,/'"mutter_api_version = ""$MUTTER_API_REPO_VER"'/{s/'"$MUTTER_API_REPO_VER"'/'"$DIFF_VALUE_2"'/g}' \
        "$blur_build_dir/meson.build"
fi

meson setup "$blur_build_dir/build" "$blur_build_dir"
meson compile -C "$blur_build_dir/build"
meson install -C "$blur_build_dir/build" --destdir "$blur_build_dir/binary"

# Stage only the runtime artifacts (6 files) into /blur-out, mirroring what
# upstream copies into /usr. The final stage will COPY --from this tree.
mkdir -p /blur-out
cp -rf "$blur_build_dir/binary/usr/local/"* /blur-out/