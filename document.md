# 机载计算机配置指南

## 修改密码与重命名

修改密码：

```bash
passwd
```

更改主机名：

```bash
sudo hostnamectl set-hostname picontrollab
```

同步修改配置：

```bash
sudo vim /etc/hosts
```

重启：

```bash
sudo reboot
```


## 安装远程桌面

网址：https://download.nomachine.com/download/?id=43&platform=linux

注意选择合适的架构：

```bash
arch
```

> 注意： NoMachine 自 10.x 版本开始，不再支持提供免费版本；建议使用 9.x 版本。

以 `arm64` 为例：

```bash

```