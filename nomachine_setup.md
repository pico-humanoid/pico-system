# NoMachine 安装与使用指南

> **注意：**
> - 自 10.x 版本起，NoMachine 官方不再允许长期免费使用，并从官网下架了历史版本的下载页面。
> - 本文档提供了 NoMachine `9.8.2` 版本的安装包：https://pan.baidu.com/s/1KnCxoJ0fRHvWHETGa-kOFQ?pwd=pico 提取码: pico 

## 下载安装

注意选取与系统相匹配的架构：

```bash
arch
```

- Windows 系统直接双击 `.exe` 安装即可。

- Linux(amd64/x86_64) 系统执行：

```bash
sudo dpkg -i YOUR_DIR/nomachine_9.8.2_1_amd64.deb
```

- Linux(arm64/aarch64) 系统执行：

```bash
sudo dpkg -i YOUR_DIR/nomachine_9.8.2_1_arm64.deb
```

## 环境配置

进入 `settings`-`status`，勾选 `Start the server at system startup` 使 NoMachine 开机自启动。

## 错误处理

如果设备连接过实体显示器，下一次启动时如果不连接显示器可能会出现图形界面加载错误，此时需关闭并重启服务：

```bash
sudo systemctl stop display-manager
sudo /etc/NX/nxserver --restart
```

