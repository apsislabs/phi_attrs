#!/usr/bin/env bash

echo "Beginning Setup"
/app/bin/setup

echo "Environment Ready"
tail -f /etc/hosts
