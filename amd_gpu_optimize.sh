#!/bin/bash

#############################################################################
# AMD GPU Optimization Script - CoreCtrl-SX
# 
# This script optimizes AMD Radeon Graphics (RDNA/RDNA2/RDNA3/GCN) for performance
# Compatible with amdgpu driver and AMDGPU PRO
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
SCRIPT_NAME="AMD GPU Optimizer"
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

# Function to detect AMD GPU
detect_amd_gpu() {
    if lspci | grep -i "amd\|ati" | grep -i "vga\|3d\|display" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to find AMD GPU cards
find_amd_cards() {
    local cards=()
    for card in /sys/class/drm/card*/device; do
        if [[ -f "$card/vendor" ]]; then
            local vendor=$(cat "$card/vendor" 2>/dev/null)
            # AMD vendor ID is 0x1002
            if [[ "$vendor" == "0x1002" ]]; then
                local card_path=$(echo "$card" | sed 's|/device||')
                local card_name=$(basename "$card_path")
                cards+=("$card_path")
            fi
        fi
    done
    echo "${cards[@]}"
}

# Function to get GPU information
get_gpu_info() {
    local cards=($(find_amd_cards))
    
    if [[ ${#cards[@]} -eq 0 ]]; then
        print_warning "No AMD GPUs found"
        return 1
    fi
    
    print_info "Detected AMD GPU(s):"
    for card in "${cards[@]}"; do
        local card_name=$(basename "$card")
        local device_path="$card/device"
        
        # Get GPU name from lspci
        local pci_slot=$(readlink "$device_path" | grep -o '[0-9a-f]\{4\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}\.[0-9]')
        local gpu_name="Unknown"
        if [[ -n "$pci_slot" ]]; then
            gpu_name=$(lspci -s "$pci_slot" | cut -d':' -f3- | sed 's/^ *//')
        fi
        
        echo "  $card_name: $gpu_name"
        
        # Get current performance level
        local perf_level="Unknown"
        if [[ -f "$device_path/power_dpm_force_performance_level" ]]; then
            perf_level=$(cat "$device_path/power_dpm_force_performance_level")
        fi
        echo "    Performance Level: $perf_level"
        
        # Get current clocks if available
        if [[ -f "$device_path/pp_dpm_sclk" ]]; then
            local current_sclk=$(grep '\*' "$device_path/pp_dpm_sclk" | cut -d':' -f2 | xargs)
            echo "    Current GPU Clock: $current_sclk"
        fi
        
        if [[ -f "$device_path/pp_dpm_mclk" ]]; then
            local current_mclk=$(grep '\*' "$device_path/pp_dpm_mclk" | cut -d':' -f2 | xargs)
            echo "    Current Memory Clock: $current_mclk"
        fi
        
        # Get temperature if available
        local temp_file=$(find "$device_path/hwmon/hwmon"* -name "temp*_input" 2>/dev/null | head -1)
        if [[ -f "$temp_file" ]]; then
            local temp=$(($(cat "$temp_file") / 1000))
            echo "    Temperature: ${temp}°C"
        fi
    done
}

# Function to set GPU performance level
set_gpu_performance() {
    local mode=$1
    local cards=($(find_amd_cards))
    
    if [[ ${#cards[@]} -eq 0 ]]; then
        print_error "No AMD GPUs found"
        return 1
    fi
    
    print_info "Setting GPU performance level to: $mode"
    
    for card in "${cards[@]}"; do
        local card_name=$(basename "$card")
        local device_path="$card/device"
        local perf_file="$device_path/power_dpm_force_performance_level"
        
        if [[ -f "$perf_file" ]]; then
            if check_root; then
                echo "$mode" > "$perf_file" && print_status "$card_name set to $mode" || print_error "Failed to set $card_name"
            else
                echo "$mode" | sudo tee "$perf_file" >/dev/null && print_status "$card_name set to $mode" || print_error "Failed to set $card_name (check sudo permissions)"
            fi
        else
            print_warning "$card_name: Performance control not available"
        fi
    done
}

# Function to set GPU power profile
set_gpu_power_profile() {
    local profile=$1
    local cards=($(find_amd_cards))
    
    if [[ ${#cards[@]} -eq 0 ]]; then
        print_error "No AMD GPUs found"
        return 1
    fi
    
    # Profile mappings:
    # 0: Custom
    # 1: 3D Full Screen
    # 2: Power Saving
    # 3: Video
    # 4: VR
    # 5: Compute
    # 6: Custom
    
    local profile_name=""
    case $profile in
        0) profile_name="Custom" ;;
        1) profile_name="3D Full Screen" ;;
        2) profile_name="Power Saving" ;;
        3) profile_name="Video" ;;
        4) profile_name="VR" ;;
        5) profile_name="Compute" ;;
        6) profile_name="Custom" ;;
        *) print_error "Invalid profile: $profile"; return 1 ;;
    esac
    
    print_info "Setting GPU power profile to: $profile_name"
    
    for card in "${cards[@]}"; do
        local card_name=$(basename "$card")
        local device_path="$card/device"
        local profile_file="$device_path/pp_power_profile_mode"
        
        if [[ -f "$profile_file" ]]; then
            if check_root; then
                echo "$profile" > "$profile_file" && print_status "$card_name power profile set to $profile_name" || print_error "Failed to set $card_name power profile"
            else
                echo "$profile" | sudo tee "$profile_file" >/dev/null && print_status "$card_name power profile set to $profile_name" || print_error "Failed to set $card_name power profile"
            fi
        else
            print_warning "$card_name: Power profile control not available"
        fi
    done
}

# Function to show available GPU clocks
show_available_clocks() {
    local cards=($(find_amd_cards))
    
    if [[ ${#cards[@]} -eq 0 ]]; then
        print_error "No AMD GPUs found"
        return 1
    fi
    
    for card in "${cards[@]}"; do
        local card_name=$(basename "$card")
        local device_path="$card/device"
        
        print_info "$card_name Available Settings:"
        
        # Show available GPU clocks
        if [[ -f "$device_path/pp_dpm_sclk" ]]; then
            echo "GPU Clocks (pp_dpm_sclk):"
            cat "$device_path/pp_dpm_sclk" | sed 's/^/  /'
        fi
        
        # Show available memory clocks
        if [[ -f "$device_path/pp_dpm_mclk" ]]; then
            echo "Memory Clocks (pp_dpm_mclk):"
            cat "$device_path/pp_dpm_mclk" | sed 's/^/  /'
        fi
        
        # Show available voltage states
        if [[ -f "$device_path/pp_dpm_pcie" ]]; then
            echo "PCIe States (pp_dpm_pcie):"
            cat "$device_path/pp_dpm_pcie" | sed 's/^/  /'
        fi
        
        # Show power profile modes
        if [[ -f "$device_path/pp_power_profile_mode" ]]; then
            echo "Power Profile Modes:"
            cat "$device_path/pp_power_profile_mode" | sed 's/^/  /'
        fi
        
        echo ""
    done
}

# Function to reset GPU to auto mode
reset_gpu() {
    set_gpu_performance "auto"
    print_info "GPU reset to automatic mode"
}

# Function to install AMD GPU tools
install_gpu_tools() {
    print_info "Installing AMD GPU tools..."
    
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon radeontop
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y mesa-utils vulkan-tools radeontop
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y mesa-dri-drivers vulkan-tools radeontop
    else
        print_warning "Package manager not recognized. Please install GPU tools manually."
    fi
}

# Function to enable GPU overclocking
enable_gpu_overclocking() {
    print_info "Enabling GPU overclocking features..."
    
    # Check if amdgpu.ppfeaturemask is set
    if grep -q "amdgpu.ppfeaturemask" /proc/cmdline; then
        print_status "GPU overclocking already enabled in kernel parameters"
    else
        print_warning "GPU overclocking not enabled in kernel parameters"
        print_info "To enable, add 'amdgpu.ppfeaturemask=0xffffffff' to kernel parameters"
        print_info "For GRUB: Edit /etc/default/grub and add to GRUB_CMDLINE_LINUX_DEFAULT"
        print_info "Then run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi
    
    # Create modprobe configuration
    local modprobe_file="/etc/modprobe.d/amdgpu.conf"
    if [[ ! -f "$modprobe_file" ]]; then
        if check_root; then
            echo "options amdgpu ppfeaturemask=0xffffffff" > "$modprobe_file"
            print_status "Created amdgpu modprobe configuration"
        else
            echo "options amdgpu ppfeaturemask=0xffffffff" | sudo tee "$modprobe_file" >/dev/null
            print_status "Created amdgpu modprobe configuration"
        fi
    else
        print_status "amdgpu modprobe configuration already exists"
    fi
}

# Function to show help
show_help() {
    echo "$SCRIPT_NAME v$VERSION"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  high            Set GPU to high performance mode"
    echo "  low             Set GPU to low/power-saving mode"
    echo "  auto            Set GPU to automatic mode (default)"
    echo "  manual          Set GPU to manual control mode"
    echo "  gaming          Set optimal settings for gaming (high + 3D profile)"
    echo "  compute         Set optimal settings for compute tasks"
    echo "  power-save      Set power-saving mode"
    echo "  profile <0-6>   Set power profile (0=Custom, 1=3D, 2=PowerSave, 3=Video, 4=VR, 5=Compute)"
    echo "  clocks          Show available clock speeds and states"
    echo "  status          Show current GPU status"
    echo "  reset           Reset GPU to default/auto mode"
    echo "  install         Install required GPU tools"
    echo "  enable-oc       Enable GPU overclocking support"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 gaming       # Set optimal gaming performance"
    echo "  $0 status       # Show current GPU information"
    echo "  $0 profile 1    # Set 3D Full Screen profile"
    echo "  $0 high         # Set high performance mode"
}

# Main script logic
main() {
    echo "========================================"
    echo "  $SCRIPT_NAME v$VERSION"
    echo "========================================"
    echo ""
    
    # Check if AMD GPU
    if ! detect_amd_gpu; then
        print_error "This script is designed for AMD GPUs only!"
        print_error "No AMD graphics cards detected."
        exit 1
    fi
    
    # Parse command line arguments
    case "${1:-status}" in
        "high")
            set_gpu_performance "high"
            get_gpu_info
            ;;
        "low")
            set_gpu_performance "low"
            get_gpu_info
            ;;
        "auto")
            set_gpu_performance "auto"
            get_gpu_info
            ;;
        "manual")
            set_gpu_performance "manual"
            print_info "GPU set to manual mode. Use 'clocks' command to see available settings."
            get_gpu_info
            ;;
        "gaming")
            set_gpu_performance "high"
            set_gpu_power_profile "1"  # 3D Full Screen
            get_gpu_info
            ;;
        "compute")
            set_gpu_performance "high"
            set_gpu_power_profile "5"  # Compute
            get_gpu_info
            ;;
        "power-save")
            set_gpu_performance "low"
            set_gpu_power_profile "2"  # Power Saving
            get_gpu_info
            ;;
        "profile")
            if [[ -n "$2" ]]; then
                set_gpu_power_profile "$2"
                get_gpu_info
            else
                print_error "Profile number required (0-6)"
                show_help
                exit 1
            fi
            ;;
        "clocks")
            show_available_clocks
            ;;
        "status")
            get_gpu_info
            ;;
        "reset")
            reset_gpu
            get_gpu_info
            ;;
        "install")
            install_gpu_tools
            ;;
        "enable-oc")
            enable_gpu_overclocking
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

