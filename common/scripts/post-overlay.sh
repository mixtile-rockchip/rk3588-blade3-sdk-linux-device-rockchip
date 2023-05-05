#!/bin/bash -e

source "${POST_HELPER:-$(dirname "$(realpath "$0")")/../post-hooks/post-helper}"

install_overlay()
{
	OVERLAY="$1"

	[ -d "$OVERLAY" ] || return 0

	if [ -x "$OVERLAY/install.sh" ]; then
		echo "Handling overlay: $OVERLAY..."
		"$OVERLAY/install.sh" "$TARGET_DIR" "$POST_OS"
	else
		echo "Installing overlay: $OVERLAY to $TARGET_DIR..."
		rsync -av --chmod=u=rwX,go=rX "$OVERLAY/" "$TARGET_DIR/"
	fi
}

cd "$SDK_DIR"

install_overlay "$COMMON_DIR/overlays/overlay-$POST_OS"

# No extra overlays for recovery and pcba
case "$POST_OS" in
	recovery | pcba) exit 0 ;;
esac

for overlay in "$COMMON_DIR/overlays/overlay-fonts" $RK_ROOTFS_OVERLAY_DIRS; do
	install_overlay "$overlay"
done
