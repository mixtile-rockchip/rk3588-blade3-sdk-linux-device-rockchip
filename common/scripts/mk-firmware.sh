#!/bin/bash -e

message() {
	echo -e "\e[36m$@\e[0m"
}

fatal() {
	echo -e "\e[31m$@\e[0m"
	exit 1
}

# Parse size limit from parameter.txt, 0 means unlimited or not exists.
partition_size_kb() {
	PART_NAME=$1
	PART_STR=$(grep -oE "[^,^:^\(]*\($PART_NAME[\)_:][^\)]*\)" $PARAMETER)
	PART_SIZE=$(echo $PART_STR | grep -oE "^[^@^-]*")
	echo $(( ${PART_SIZE:-0} / 2 ))
}

link_image() {
	SRC="$1"
	DST="$2"
	FALLBACK="$3"

	message "Linking $DST from $SRC..."

	if [ ! -f "$SRC" ]; then
		if [ -f "$FALLBACK" ]; then
			SRC="$FALLBACK"
			message "Fallback to $SRC"
		else
			message "warning: $SRC not found!"
			return 1
		fi
	fi

	ln -rsf "$SRC" "$RK_FIRMWARE_DIR/$DST"

	message "Done linking $DST"
}

link_image_optional() {
	link_image "$@" || true
}

pack_extra_partitions() {
	source "$PARTITION_HELPER"

	for idx in $(seq 1 "$(rk_partition_num)"); do
		# Skip built-in partitions
		if rk_partition_builtin $idx; then
			continue
		fi

		# Check generated dir and script (in post-rootfs stage)
		FAKEROOT_SCRIPT="$(rk_partition_fakeroot_script $idx)"
		OUTDIR="$(rk_partition_outdir $idx)"
		if [ ! -r "$FAKEROOT_SCRIPT" -o ! -d "$OUTDIR" ]; then
			fatal "Rootfs not ready?"
		fi

		DST="$(rk_partition_img $idx)"

		message "Packing $DST from $FAKEROOT_SCRIPT"
		cd "$OUTDIR"
		fakeroot -- "$FAKEROOT_SCRIPT"
		message "Done packing $DST"
	done
}

build_firmware()
{
	if ! which fakeroot &>/dev/null; then
		echo "fakeroot not found! (sudo apt-get install fakeroot)"
		exit 1
	fi

	PARAMETER="$CHIP_DIR/$RK_PARAMETER"
	MISC_IMG="$RK_IMAGE_DIR/${RK_MISC_IMG:-blank-misc.img}"
	MKIMAGE="$SCRIPTS_DIR/mk-image.sh"

	mkdir -p "$RK_FIRMWARE_DIR"

	link_image_optional "$PARAMETER" parameter.txt
	link_image_optional "$MISC_IMG" misc.img

	pack_extra_partitions

	echo "Packed files:"
	for f in "$RK_FIRMWARE_DIR"/*; do
		NAME=$(basename "$f")

		echo -n "$NAME"
		if [ -L "$f" ]; then
			echo -n "($(readlink -f "$f"))"
		fi

		FILE_SIZE=$(ls -lLh $f | xargs | cut -d' ' -f 5)
		echo ": $FILE_SIZE"


		echo "$NAME" | grep -q ".img$" || continue

		# Assert the image's size smaller than parameter.txt's limit
		PART_SIZE="$(partition_size_kb "${NAME%.img}")"
		[ ! "$PART_SIZE" -eq 0 ] || continue

		FILE_SIZE_KB="$(( $(stat -Lc "%s" "$f") / 1024 ))"
		if [ "$PART_SIZE" -lt "$FILE_SIZE_KB" ]; then
			fatal "error: $NAME's size exceed parameter's limit!"
		fi
	done

	message "Images in $RK_FIRMWARE_DIR are ready!"

	finish_build
}

# Hooks

usage_hook()
{
	echo "firmware           - generate and check firmwares"
}

clean_hook()
{
	rm -rf "$RK_FIRMWARE_DIR"
	mkdir -p "$RK_FIRMWARE_DIR"
}

POST_BUILD_CMDS="firmware"
post_build_hook()
{
	build_firmware
}

source "${BUILD_HELPER:-$(dirname "$(realpath "$0")")/../build-hooks/build-helper}"

build_firmware $@
