#!/bin/bash
for dir in */; do
    [ -f "$dir/merge.sh" ] && (cd "$dir" && bash merge.sh)
done
echo "All done"
