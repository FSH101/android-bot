#!/usr/bin/env sh

# Minimal Gradle wrapper proxy script for environments without network access.
# Delegates to the system Gradle installation.
exec gradle "$@"
