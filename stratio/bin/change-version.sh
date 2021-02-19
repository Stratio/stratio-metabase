#!/bin/bash -e

BASEDIR=$( cd "$(dirname "$0")" ; pwd -P )/../..

cd "$BASEDIR"

if [[ -z "$1" ]]; then
	VERSION=$(cat "$BASEDIR"/VERSION)
else
	VERSION=$1
fi

echo "Modifying Installer version to: $VERSION"

echo $VERSION > VERSION
