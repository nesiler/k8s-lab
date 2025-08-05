#!/bin/bash

# Platform-specific utility functions

# OS Detection
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Base64 decode (platform agnostic)
base64_decode() {
    local input="$1"
    local os=$(detect_os)
    
    if [ "$os" == "macos" ]; then
        echo "$input" | base64 --decode
    else
        echo "$input" | base64 -d
    fi
}

# Open URL in browser
open_url() {
    local url="$1"
    local os=$(detect_os)
    
    if [ "$os" == "macos" ]; then
        open "$url" 2>/dev/null || true
    elif [ "$os" == "linux" ]; then
        xdg-open "$url" 2>/dev/null || true
    elif [ "$os" == "windows" ]; then
        start "$url" 2>/dev/null || true
    else
        echo "Please open manually: $url"
    fi
}

# Get memory in GB
get_system_memory_gb() {
    local os=$(detect_os)
    
    if [ "$os" == "macos" ]; then
        echo $(($(sysctl -n hw.memsize) / 1073741824))
    elif [ "$os" == "linux" ]; then
        echo $(free -g | awk '/^Mem:/{print $2}')
    else
        echo "0"
    fi
}

# Check if running in container
is_in_container() {
    if [ -f /.dockerenv ]; then
        return 0
    elif grep -q docker /proc/1/cgroup 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get number of CPU cores
get_cpu_cores() {
    local os=$(detect_os)
    
    if [ "$os" == "macos" ]; then
        sysctl -n hw.ncpu
    elif [ "$os" == "linux" ]; then
        nproc
    else
        echo "4"  # default
    fi
}

# Kill process by port
kill_port() {
    local port="$1"
    local os=$(detect_os)
    
    if [ "$os" == "macos" ]; then
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
    elif [ "$os" == "linux" ]; then
        fuser -k $port/tcp 2>/dev/null || true
    fi
}

# Export functions
export -f detect_os
export -f base64_decode
export -f open_url
export -f get_system_memory_gb
export -f is_in_container
export -f get_cpu_cores
export -f kill_port