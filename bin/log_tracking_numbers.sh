#!/bin/bash

export PATH="$HOME/.rbenv/bin:$PATH"

if command -v rbenv &> /dev/null; then
    eval "$(rbenv init -)"
fi
DISABLE_SPRING=1 rails r bin/log_central_tracking_numbers.rb