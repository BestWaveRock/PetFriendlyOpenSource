#!/bin/sh
set -eu

ARTIFACT_DIR="${ARTIFACT_DIR:-${WORKSPACE:-.}/artifacts}"
VERSION_FILE="${VERSION_FILE:-$ARTIFACT_DIR/last_built_version.txt}"
if [ ! -s "$VERSION_FILE" ]; then
  echo "NOTICE SKIPPED: version file not found: $VERSION_FILE"
  exit 0
fi

RELEASE_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
NOTES_FILE="release-notes/$RELEASE_VERSION.md"
if [ ! -f "$NOTES_FILE" ]; then
  VERSION_LINE=$(printf '%s' "$RELEASE_VERSION" | awk -F. '{print $1"."$2".0"}')
  NOTES_FILE="release-notes/$VERSION_LINE.md"
fi
if [ ! -f "$NOTES_FILE" ]; then
  echo "NOTICE SKIPPED: no release notes for $RELEASE_VERSION"
  exit 0
fi

MYSQL_JAR=${MYSQL_CONNECTOR_JAR:-}
if [ -z "$MYSQL_JAR" ]; then
  MYSQL_JAR=$(find "${M2_REPO:-$HOME/.m2}" -name 'mysql-connector-j-*.jar' -type f 2>/dev/null | sort -V | tail -1 || true)
fi
if [ -z "$MYSQL_JAR" ] || [ ! -f "$MYSQL_JAR" ]; then
  echo "NOTICE SKIPPED: MySQL Connector/J not found"
  exit 0
fi

java --class-path "$MYSQL_JAR" script/release/publish_release_notice.java "$RELEASE_VERSION" "$NOTES_FILE"
