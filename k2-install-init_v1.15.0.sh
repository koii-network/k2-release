KOII_RELEASE=v1.15.0
KOII_INSTALL_INIT_ARGS=v1.15.0

# This is just a little script that can be downloaded from the internet to
# install koii-install. It just does platform detection, downloads the installer
# and runs it.

{ # this ensures the entire script is downloaded #

if [ -z "$KOII_DOWNLOAD_ROOT" ]; then
    KOII_DOWNLOAD_ROOT="https://github.com/koii-network/k2-release/releases/download"
fi
GH_LATEST_RELEASE="https://api.github.com/repos/koii-network/k2-release/releases/latest"

set -e

usage() {
    cat 1>&2 <<EOF
koii-install-init
initializes a new installation

USAGE:
    koii-install-init [FLAGS] [OPTIONS] --data_dir <PATH> --pubkey <PUBKEY>

FLAGS:
    -h, --help              Prints help information
        --no-modify-path    Don't configure the PATH environment variable

OPTIONS:
    -d, --data_dir <PATH>    Directory to store install data
    -u, --url <URL>          JSON RPC URL for the koii cluster
    -p, --pubkey <PUBKEY>    Public key of the update manifest
EOF
}

main() {
    downloader --check
    need_cmd uname
    need_cmd mktemp
    need_cmd chmod
    need_cmd mkdir
    need_cmd rm
    need_cmd sed
    need_cmd grep

    for arg in "$@"; do
      case "$arg" in
        -h|--help)
          usage
          exit 0
          ;;
        *)
          ;;
      esac
    done

    case "$(uname)" in
    Linux)
      TARGET=x86_64-unknown-linux-gnu
      ;;
    Darwin)
      TARGET=x86_64-apple-darwin
      ;;
    *)
      err "machine architecture is currently unsupported"
      ;;
    esac

    temp_dir="$(mktemp -d 2>/dev/null || ensure mktemp -d -t koii-install-init)"
    ensure mkdir -p "$temp_dir"

    # Check for KOII_RELEASE environment variable override.  Otherwise fetch
    # the latest release tag from github
    if [ -n "$KOII_RELEASE" ]; then
      release="$KOII_RELEASE"
    else
      release_file="$temp_dir/release"
      printf 'looking for latest release\n' 1>&2
      ensure downloader "$GH_LATEST_RELEASE" "$release_file"
      release=$(\
        grep -m 1 \"tag_name\": "$release_file" \
        | sed -ne 's/^ *"tag_name": "\([^"]*\)",$/\1/p' \
      )
      if [ -z "$release" ]; then
        err 'Unable to figure latest release'
      fi
    fi

    download_url="$KOII_DOWNLOAD_ROOT/$release/koii-install-init-$TARGET"
    koii_install_init="$temp_dir/koii-install-init"

    printf 'downloading %s installer\n' "$release" 1>&2

    ensure mkdir -p "$temp_dir"
    ensure downloader "$download_url" "$koii_install_init"
    ensure chmod u+x "$koii_install_init"
    if [ ! -x "$koii_install_init" ]; then
        printf '%s\n' "Cannot execute $koii_install_init (likely because of mounting /tmp as noexec)." 1>&2
        printf '%s\n' "Please copy the file to a location where you can execute binaries and run ./koii-install-init." 1>&2
        exit 1
    fi

    if [ -z "$1" ]; then
      #shellcheck disable=SC2086
      ignore "$koii_install_init" $KOII_INSTALL_INIT_ARGS
    else
      ignore "$koii_install_init" "$@"
    fi
    retval=$?

    ignore rm "$koii_install_init"
    ignore rm -rf "$temp_dir"

    return "$retval"
}

err() {
    printf 'koii-install-init: %s\n' "$1" >&2
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    if ! "$@"; then
      err "command failed: $*"
    fi
}

# This is just for indicating that commands' results are being
# intentionally ignored. Usually, because it's being executed
# as part of error handling.
ignore() {
    "$@"
}

# This wraps curl or wget. Try curl first, if not installed,
# use wget instead.
downloader() {
    if check_cmd curl; then
        program=curl
    elif check_cmd wget; then
        program=wget
    else
        program='curl or wget' # to be used in error message of need_cmd
    fi

    if [ "$1" = --check ]; then
        need_cmd "$program"
    elif [ "$program" = curl ]; then
        curl -sSfL "$1" -o "$2"
    elif [ "$program" = wget ]; then
        wget "$1" -O "$2"
    else
        err "Unknown downloader"   # should not reach here
    fi
}

main "$@"

} # this ensures the entire script is downloaded #
