#!/bin/sh -i

# This is an ugly shim to work around some requirement that vm-bhyve have an
# interactive shell when calling 'vm start'. This script specifies an
# interactive shell, which allows the script to work.

vm start "$1"
