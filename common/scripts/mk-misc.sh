#!/bin/bash -e

# Hooks

usage_hook()
{
	echo -e "misc                              \tpack misc image"
}

clean_hook()
{
	rm -rf "$RK_FIRMWARE_DIR/misc.img"
	rm -rf "$RK_ROCKDEV_DIR/misc.img"
}

BUILD_CMDS="misc"
build_hook()
{
	MISC_IMG="$RK_FIRMWARE_DIR/misc.img"
	rm -f "$MISC_IMG"

	check_config MISC_IMG || false

	if [ -z "$(rk_partition_size misc)" ]; then
		notice "Misc ignored"
		return 0
	fi

	# The old windows tools don't accept misc > 64K
	truncate -s 48k "$MISC_IMG"

	if [ "$RK_MISC_BLANK" ]; then
		notice "Generated blank misc image"
	elif [ "$RK_MISC_RECOVERY" ]; then
		echo -n "boot-recovery" | \
			dd of="$MISC_IMG" bs=1 seek=$((16*1024)) conv=notrunc
		echo -e -n "recovery\n$RK_MISC_RECOVERY_ARG" | \
			dd of="$MISC_IMG" bs=1 seek=$((16*1024+64)) conv=notrunc
		notice "Generated recovery misc with: $RK_MISC_RECOVERY_ARG"
	else
		ln -rvsf "$RK_CHIP_DIR/$RK_MISC_IMG" "$MISC_IMG"
	fi

	notice "Done packing $MISC_IMG"

	if grep -wq boot-recovery "$MISC_IMG" && \
		[ -z "$(rk_partition_size recovery)" ]; then
		error "Recovery misc requires recovery partition!"
		return 1
	fi

	finish_build build_misc
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/../build-hooks/build-helper}"

build_hook
