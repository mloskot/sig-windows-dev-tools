#!/bin/bash
set -euo pipefail
go run -buildvcs=true ./main.go "$@"
