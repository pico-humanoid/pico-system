# CMP10A-IMU 使用说明

本文档使用的是亚博智能 (Yahboom) 十轴惯性传感器 ([CMP10A-IMU](https://www.yahboom.com/study/IMU))，“十轴”是指：

- 3轴加速度： $a_x,a_y,a_z$
- 3轴角速度： $\omega_x,\omega_y,\omega_z$
- 3轴磁力计： $m_x,m_y,m_z$
- 1轴气压计： $P$

## 准备工作

### 安装位置

- 在人形机器人运动控制的过程中，通常将浮动基座的坐标系原点选取为整个系统的质心。
- 因此，一般将 IMU 尽可能准确地安装于**质心**位置，从而减少姿态变换的误差。

### 驱动软件

- CMP10A-IMU 采用串口通讯协议，基于 **CP2102** 通过 USB 与上位机（如PC、Jestson等）进行数据交互。
- 因此，使用前需确保已装有 CP2102 驱动软件。

#### Windows

#### Linux/Ubuntu

- Linux/Ubuntu 系统默认已装有 CP210x 驱动，一般不需额外操作。

## 使用方法

### Step-1 连接设备 

1. 将 CMPA10A IMU 通过 USB 线插入主机设备，等待几秒后执行
   ```bash
   lsusb
   ```
   应当能看到类似 `Bus 001 Device 007: ID 10c4:ea60 Silicon Labs CP210x UART Bridge` 的输出；如果没有则尝试重新插拔设备。
2. 继续检查
   ```bash
   ls /dev/ttyUSB* /dev/serial/by-id/*
   ```
   应当能看到类似 `/dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0` 和 `/dev/ttyUSB0` 的输出

### Step-2 安装 Python SDK

1. 获取 PICO-Humanoid 软件包并进入
   ```bash
   git clone https://github.com/pico-humanoid/pico-packages.git && cd pico-packages
   ```
2. 其余步骤详见 [pico_py.imu使用指南](https://github.com/pico-humanoid/pico-packages/blob/main/pico_py/README.md)

### Step-3 工作测试

- 数据读取测试（基于自身 Python SDK）

- 可视化测试（基于ROS2包）