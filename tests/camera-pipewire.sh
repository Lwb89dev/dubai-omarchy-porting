#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

for command in pw-dump gst-launch-1.0 python3 timeout stat; do
    command -v "$command" >/dev/null
done

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

mapfile -t nodes < <(pw-dump | python3 -c '
import json, sys
for obj in json.load(sys.stdin):
    props = obj.get("info", {}).get("props", {})
    name = props.get("node.name", "")
    if props.get("media.class") == "Video/Source" and name.startswith("libcamera_input."):
        print(name)
')

((${#nodes[@]} == 2)) || {
    echo "Expected two libcamera sources, found ${#nodes[@]}" >&2
    exit 1
}

for node in "${nodes[@]}"; do
    output=$workdir/${node}.rgba
    timeout --foreground 30 gst-launch-1.0 -q -e \
        pipewiresrc target-object="$node" num-buffers=5 ! \
        video/x-raw,format=RGBA,width=640,height=480,framerate=30/1 ! \
        filesink location="$output"
    size=$(stat -c %s "$output")
    ((size == 640 * 480 * 4 * 5)) || {
        echo "$node: unexpected capture size $size" >&2
        exit 1
    }
    echo "$node: five RGBA frames captured"
done
