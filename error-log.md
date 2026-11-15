\# 脚本踩坑记录

\## 问题1

报错：./server\_check.sh: line 5: data: command not found

原因：单词拼写错误，把 date 写成 data

解决：修改脚本，data → date



\## 问题2：vi 命令找不到

报错：-bash: vi: command not found

原因：CentOS7 最小化安装，默认没有预装 vi 软件包

解决：

yum install -y vim-minimal



\## 问题3：vim 命令找不到

报错：-bash: vim: command not found

原因：最小化系统只自带简易版vi，完整版vim没有安装

解决：

yum install -y vim-enhanced

