#!/bin/bash -e

SCRIPTS_DIR="$(dirname "$(realpath "$BASH_SOURCE")")"
DEVICE_DIR="$(realpath "$SCRIPTS_DIR/../../")"
CHIPS_DIR="$DEVICE_DIR/.chips"
CHIP_DIR="$DEVICE_DIR/.chip"

choose_chip()
{
	CHIP_ARRAY=( $(ls "$CHIPS_DIR") )
	CHIP_ARRAY_LEN=${#CHIP_ARRAY[@]}
	echo "Pick a chip:"
	echo ""

	echo ${CHIP_ARRAY[@]} | xargs -n 1 | sed "=" | sed "N;s/\n/. /"

	local INDEX
	read -p "Which would you like? [1]: " INDEX
	INDEX=$((${INDEX:-1} - 1))
	CHIP="${CHIP_ARRAY[$INDEX]}"
}

CHIP=$1
if [ -z "$CHIP" -o ! -e "$CHIPS_DIR/$CHIP" ]; then
	choose_chip
	[ "$CHIP" ] || exit 1
fi

echo "Releasing chip: $CHIP"

cd "$DEVICE_DIR"

COMMIT_MSG=$(mktemp)
cat << EOF > $COMMIT_MSG
Release $CHIP - $(date +%Y-%m-%d)

Based on:
$(git log -1 --format="%h %s")
EOF

git add -f .
git stash

git branch -D $CHIP &>/dev/null || true
git checkout --orphan $CHIP
git reset

rm -f "$CHIP_DIR"
ln -rsf "$CHIPS_DIR/$CHIP" "$CHIP_DIR"
ln -rsf "$CHIPS_DIR/$CHIP" .

git add -f .gitignore common "$CHIPS_DIR/$CHIP" "$CHIP_DIR" "$CHIP"
git commit -s -F $COMMIT_MSG

git add -f .
git stash
