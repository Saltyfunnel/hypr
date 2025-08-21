#!/bin/bash

updates=$(checkupdates 2>/dev/null | wc -l)

if [ "$updates" -gt 0 ]; then
  echo "$updates"
else
  echo "0"
fi
