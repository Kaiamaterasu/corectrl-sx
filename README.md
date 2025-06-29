# CoreCtrl-SX Optimization Scripts

This repository contains optimization scripts for AMD CPUs and GPUs designed to enhance performance and adjust power settings.

## AMD CPU Optimization Script

The CPU optimization script allows you to:

- Set the CPU to performance mode
- Enable or disable CPU boost
- Display current CPU status and frequencies

### Usage

```bash
./amd_cpu_optimize.sh [option]
```

### Options

- `performance`: Set the CPU to performance mode and enable boost
- `powersave`: Set the CPU to powersave mode
- `boost-on`: Enable CPU boost
- `boost-off`: Disable CPU boost
- `status`: Show current CPU status
- `install`: Install required dependencies
- `help`: Show help message

## AMD GPU Optimization Script

The GPU optimization script allows you to:

- Set the GPU to high or low performance mode
- Adjust power profiles for gaming, compute, or power-saving
- Display current GPU status and available settings

### Usage

```bash
./amd_gpu_optimize.sh [option]
```

### Options

- `high`: Set GPU to high performance mode
- `low`: Set GPU to low/power-saving mode
- `auto`: Set GPU to automatic mode
- `manual`: Set GPU to manual control mode
- `gaming`: Set optimal settings for gaming
- `compute`: Set optimal settings for compute tasks
- `power-save`: Set power-saving mode
- `profile <0-6>`: Set power profile
- `status`: Show current GPU status
- `reset`: Reset GPU to default/auto mode
- `install`: Install required GPU tools
- `enable-oc`: Enable GPU overclocking support
- `help`: Show help message

## License

MIT License

