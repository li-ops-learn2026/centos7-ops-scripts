# 脚本踩坑记录

记录编写脚本和配置 Linux 环境时踩过的坑。

## 问题 1：date 被写成了 data

**报错**

```text
./server_check.sh: line 5: data: command not found
```

**原因**

单词拼写错误，把 `date` 写成了 `data`。

**解决**

修改脚本，把 `data` 改成 `date`。

## 问题 2：vi 命令找不到

**报错**

```text
-bash: vi: command not found
```

**原因**

CentOS 7 最小化安装，默认没有预装 vi 软件包。

**解决**

```bash
yum install -y vim-minimal
```

## 问题 3：vim 命令找不到

**报错**

```text
-bash: vim: command not found
```

**原因**

最小化系统只自带简易版 vi，完整版 vim 没有安装。

**解决**

```bash
yum install -y vim-enhanced
```
