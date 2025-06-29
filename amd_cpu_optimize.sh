#!/bin/bash

#############################################################################
# AMD CPU Optimization Script - CoreCtrl-SX
# 
# This script optimizes AMD Ryzen/EPYC processors for maximum performance
# Compatible with all AMD processors supporting amd_pstate driver
#
# Author: CoreCtrl-SX Project
# License: MIT
# Version: 1.0
#############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script information
SCRIPT_NAME="AMD CPU Optimizer"
VERSION="1.0"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to detect AMD CPU
detect_amd_cpu() {
    if grep -q "AuthenticAMD" /proc/cpuinfo; then
        return 0
    else
        return 1
    fi
}

# Function to get CPU information
get_cpu_info() {
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    local cpu_cores=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    local cpu_threads=$(nproc)
    local current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "Unknown")
    
    echo "CPU Model: $cpu_model"
    echo "CPU Cores: $cpu_cores"
    echo "CPU Threads: $cpu_threads"
    echo "Current Governor: $current_governor"
}

# Function to check available governors
check_governors() {
    local available_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
    echo "Available governors: $available_governors"
}

# Function to set CPU performance mode
set_performance_mode() {
    print_info "Setting CPU to performance mode..."
    
    if check_root; then
        # Direct method for root
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo performance > "$cpu" 2>/dev/null && print_status "Set $(basename $(dirname $cpu)) to performance" || print_warning "Failed to set $(basename $(dirname $cpu))"
        done
    else
        # Using cpupower for non-root (requires sudo)
        if command -v cpupower >/dev/null 2>&1; then
            sudo cpupower frequency-set -g performance >/dev/null 2>&1 && print_status "CPU governor set to performance" || print_error "Failed to set CPU governor (try running with sudo)"
        else
            print_error "cpupower not found. Install with: sudo pacman -S cpupower"
            return 1
        fi
    fi
}

# Function to set CPU power save mode
set_powersave_mode() {
    print_info "Setting CPU to power save mode..."
    
    if check_root; then
        # Direct method for root
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo powersave > "$cpu" 2>/dev/null && print_status "Set $(basename $(dirname $cpu)) to powersave" || print_warning "Failed to set $(basename $(dirname $cpu))"
        done
    else
        # Using cpupower for non-root (requires sudo)
        if command -v cpupower >/dev/null 2>&1; then
            sudo cpupower frequency-set -g powersave >/dev/null 2>&1 && print_status "CPU governor set to powersave" || print_error "Failed to set CPU governor (try running with sudo)"
        else
            print_error "cpupower not found. Install with: sudo pacman -S cpupower"
            return 1
        fi
    fi
}

# Function to enable/disable CPU boost
toggle_cpu_boost() {
    local boost_file="/sys/devices/system/cpu/cpufreq/boost"
    local action=$1
    
    if [[ ! -f "$boost_file" ]]; then
        print_warning "CPU boost control not available on this system"
        return 1
    fi
    
    if check_root; then
        if [[ "$action" == "enable" ]]; then
            echo 1 > "$boost_file" && print_status "CPU boost enabled" || print_error "Failed to enable CPU boost"
        elif [[ "$action" == "disable" ]]; then
            echo 0 > "$boost_file" && print_status "CPU boost disabled" || print_error "Failed to disable CPU boost"
        fi
    else
        if [[ "$action" == "enable" ]]; then
            echo 1 | sudo tee "$boost_file" >/dev/null && print_status "CPU boost enabled" || print_error "Failed to enable CPU boost"
        elif [[ "$action" == "disable" ]]; then
            echo 0 | sudo tee "$boost_file" >/dev/null && print_status "CPU boost disabled" || print_error "Failed to disable CPU boost"
        fi
    fi
}

# Function to show current CPU status
show_cpu_status() {
    print_info "Current CPU Status:"
    echo "===================="
    get_cpu_info
    echo ""
    check_governors
    echo ""
    
    # Check boost status
    local boost_file="/sys/devices/system/cpu/cpufreq/boost"
    if [[ -f "$boost_file" ]]; then
        local boost_status=$(cat "$boost_file")
        if [[ "$boost_status" == "1" ]]; then
            echo "CPU Boost: Enabled"
        else
            echo "CPU Boost: Disabled"
        fi
    else
        echo "CPU Boost: Not available"
    fi
    
    # Show current frequencies
    echo ""
    print_info "Current CPU Frequencies:"
    for i in {0..3}; do
        if [[ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" ]]; then
            local freq=$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq")
            local freq_mhz=$((freq / 1000))
            echo "CPU$i: ${freq_mhz} MHz"
        fi
    done
}

# Function to install required packages
install_dependencies() {
    print_info "Installing required packages..."
    
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm cpupower
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y linux-cpupower
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y kernel-tools
    else
        print_warning "Package manager not recognized. Please install cpupower manually."
    fi
}

# Function to show help
show_help() {
    echo "$SCRIPT_NAME v$VERSION"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  performance     Set CPU to performance mode"
    echo "  powersave       Set CPU to power save mode"
    echo "  boost-on        Enable CPU boost"
    echo "  boost-off       Disable CPU boost"
    echo "  status          Show current CPU status"
    echo "  install         Install required dependencies"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 performance  # Set CPU to maximum performance"
    echo "  $0 status       # Show current CPU information"
    echo "  $0 boost-on     # Enable CPU frequency boost"
}

# Main script logic
main() {
    echo "========================================"
    echo "  $SCRIPT_NAME v$VERSION"
    echo "========================================"
    echo ""
    
    # Check if AMD CPU
    if ! detect_amd_cpu; then
        print_error "This script is designed for AMD processors only!"
        print_error "Detected: $(grep "vendor_id" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)"
        exit 1
    fi
    
    # Parse command line arguments
    case "${1:-status}" in
        "performance")
            set_performance_mode
            toggle_cpu_boost "enable"
            show_cpu_status
            ;;
        "powersave")
            set_powersave_mode
            show_cpu_status
            ;;
        "boost-on")
            toggle_cpu_boost "enable"
            show_cpu_status
            ;;
        "boost-off")
            toggle_cpu_boost "disable"
            show_cpu_status
            ;;
        "status")
            show_cpu_status
            ;;
        "install")
            install_dependencies
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    print_info "Script completed successfully!"
}

# Run main function
main "$@"

