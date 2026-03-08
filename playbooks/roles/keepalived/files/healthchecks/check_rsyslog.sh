#!/usr/bin/env bash

if echo -e '\035\nquit' | telnet 127.0.0.1 514 >/dev/null 2>&1; then
  exit 0
else
  exit 1
fi
