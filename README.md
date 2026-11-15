# CentOS 7 服务器巡检 Shell 脚本

## ✅ 项目简介

这是一个面向 CentOS 7 的简易服务器巡检脚本，一键获取服务器基础信息，适合云计算运维练习。

脚本可以输出：

- 主机名称
- 操作系统版本
- 系统当前时间
- CPU 负载信息
- 内存使用情况
- 磁盘占用情况
- 本机监听端口

## 📌 运行环境

CentOS 7

## 📝 使用步骤

1. 将 `server_check.sh` 上传到 CentOS 7 服务器

2. 给脚本添加执行权限

   ```bash
   chmod +x server_check.sh
   ```

3. 执行脚本

   ```bash
   ./server_check.sh
   ```

## ⚠️ 踩坑记录

详细报错原因和解决方案请看：[error-log.md](error-log.md)

## 📂 文件说明

- `server_check.sh`：巡检脚本主体
- `error-log.md`：实操遇到的报错、原因以及解决办法
