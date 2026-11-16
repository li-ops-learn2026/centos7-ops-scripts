# 环境踩坑记录

记录配置 CentOS 7 环境时踩过的坑，本篇只保留 **vi / vim 编辑器**、**网络配置与重启**、**脚本粘贴与文件写入**、**定时任务** 相关的内容。

只收能复现、根因不直观、处理有代价的问题。操作失误（在编辑器里误执行了命令、粘错了窗口、忘了 `chmod`）不收录，那类问题靠习惯和校验命令解决，写进文档也防不住第二次。

环境：CentOS 7 x86_64 最小化安装，bash 4.2，`vi` 来自 `vim-minimal` 7.4。

---

## 一、vi / vim 相关

### 问题 1：vi 命令找不到

**报错**

```text
-bash: vi: command not found
```

**原因**

CentOS 7 最小化安装，没有预装任何 vi 软件包。

**解决**

```bash
yum install -y vim-minimal
```

装完即可使用 `vi`（只有基础编辑功能，无语法高亮）。

### 问题 2：vi 能用，vim 命令找不到

**报错**

```text
-bash: vim: command not found
```

**原因**

最小化系统只装了简易版 `vim-minimal`，完整版 `vim-enhanced` 没有安装，所以 `vi` 可用、`vim` 不可用。

**解决**

```bash
yum install -y vim-enhanced
```

装完 `vim` 具备语法高亮、多窗口、撤销树等完整功能。

### 问题 3：装了 vim-enhanced，vi 仍然是简易版

**原因**

`vi` 与 `vim` 是两个独立的可执行文件：`vi` 由 `vim-minimal` 提供，`vim` 由 `vim-enhanced` 提供，装完整版不会替换 `vi`。

**解决**

两种方式任选：

```bash
# 方式一：直接用 vim 命令
vim server_check.sh

# 方式二：给 vi 做别名，使 vi 等价于 vim
echo "alias vi='vim'" >> /etc/bashrc
source /etc/bashrc
```

确认当前系统里到底有哪些编辑器，别靠猜：

```bash
rpm -qf "$(command -v vi)"
rpm -q vim-minimal vim-enhanced
command -v vi vim
```

### 问题 4：最小化系统没有 yum 源装不了 vim

**原因**

内网环境或 yum 源不可用，`yum install` 直接失败，`/etc/yum.repos.d/` 里的源指向外网。

**解决**

方式一：挂载系统光盘作为本地源再安装。

```bash
mkdir -p /mnt/cdrom
mount -o ro /dev/sr0 /mnt/cdrom

cat > /etc/yum.repos.d/local.repo <<'REPO'
[local]
name=local
baseurl=file:///mnt/cdrom
enabled=1
gpgcheck=0
REPO

yum --disablerepo='*' --enablerepo=local install -y vim-minimal
```

几个容易卡住的点：

- `mount` 报 `no medium found`，是虚拟机光驱里没插 ISO，先去虚拟化平台挂载。
- 报 `Cannot retrieve repository metadata`，多半是 `baseurl` 指错了目录，`repodata/` 必须就在 `baseurl` 下。
- `gpgcheck=0` 是跳过签名校验，因为光盘的 GPG key 还没导入。导入之后可以改回 `gpgcheck=1`：

  ```bash
  rpm --import /mnt/cdrom/RPM-GPG-KEY-CentOS-7
  ```

- `--disablerepo='*'` 必须加，否则 yum 仍会去连外网源，卡在超时上。

方式二：完全不用编辑器，用重定向直接写文件（巡检脚本推荐这种方式，见第三章）。

```bash
cat > /root/server_check.sh <<'EOF'
#!/bin/bash
echo hello
EOF
chmod +x /root/server_check.sh
```

### 问题 5：在 vi 里粘贴多行代码，缩进会逐行加深

**现象**

粘贴一段缩进规整的脚本，越往下缩进越多，`if` / `fi` / `case` 的层级全部跑版；行数看着对，结构已经坏了。

**原因**

插入模式下 `autoindent` 按上一行的缩进给新行重新缩进，而粘贴进来的一整块文本在 vi 看来是连续的手工输入，每一行都会被重新算一遍缩进。

**解决**

```text
:set paste      # 先设置，再按 i 进入插入模式
...粘贴...
Esc
:set nopaste
```

`:set paste` 同时会关掉自动缩进、缩写展开等输入辅助，所以粘完必须 `:set nopaste` 恢复，否则之后正常编辑的手感会很怪。

要整段写文件，用 heredoc 比在 vi 里粘贴可靠得多，见「三、脚本粘贴与文件写入相关」问题 2。

---

## 二、网络配置与重启

### 问题 1：改完 IP 不生效，或改完注释没了

**现象**

手改 `ifcfg-ens33` 里的 `IPADDR` 后不重启服务就不生效；用 `nmcli connection modify` 改过一次之后，文件里的注释和自定义行消失了。

**原因**

CentOS 7 网卡配置文件在 `/etc/sysconfig/network-scripts/ifcfg-<网卡名>`，改完必须让服务重新加载才生效。NetworkManager 的 ifcfg-rh 插件只在 `reload` 之后才重新读文件；反向地，`nmcli ... modify` 是按 NM 内部模型重写整个 ifcfg 文件，注释这类它不理解的内容会被丢掉。

**解决**

```bash
# 手改之后：让服务重新加载并启用网卡
nmcli connection reload
nmcli connection up ens33

# 由 NM 托管就别在 ifcfg 里写注释，用 nmcli 改
nmcli connection modify ens33 ipv4.addresses 192.168.1.10/24
```

顺便确认 `ONBOOT=yes`，否则重启系统后网卡不会自动启用，表现是「配置都对但没网」。重点项：`BOOTPROTO` / `IPADDR` / `PREFIX` 或 `NETMASK` / `GATEWAY` / `DNS1` / `ONBOOT`。

### 问题 2：systemctl restart network 报错失败

**报错**

```text
Job for network.service failed because the control process exited with error code.
See "systemctl status network.service" and "journalctl -xe" for details.
```

**先看日志，别看错地方**

按提示执行 `journalctl -xe | tail -30` 经常什么都看不出来：真正的原因夹在输出中间，末尾全是无关的 systemd 行。按单元过滤才看得见：

```bash
systemctl status network -l --no-pager
journalctl -u network -n 50 --no-pager
```

**原因（常见三类）**

1. 配置不完整：`ifcfg-` 文件里 `BOOTPROTO=none` 但没写 `IPADDR`，或 `PREFIX` / `NETMASK` 缺失；
2. 网卡标识冲突：从模板复制 `ifcfg-` 文件时没改 `DEVICE` 和 `NAME`，或两个配置文件里 `UUID` 相同；
3. `NetworkManager` 与 `network` 同时管理同一块网卡，互相抢占。

**解决**

```bash
cat /etc/sysconfig/network-scripts/ifcfg-ens33   # 逐项核对
uuidgen                                          # 需要时生成新 UUID 写回
```

`DEVICE` 必须和文件名一致（`ifcfg-ens33` 里就是 `DEVICE=ens33`），否则服务找不到对应网卡。确认无误后：

```bash
systemctl stop NetworkManager
systemctl restart network
```

### 问题 3：NetworkManager 和 network 冲突

**现象**

`restart network` 报失败，但 `ip a` 里地址其实是有的；或者重启系统后 IP 又变回旧值。

**原因**

CentOS 7 同时存在 `network`（传统）和 `NetworkManager`（新）两套网络管理服务，两者都开机自启时，后启动的会覆盖前者写下的配置，谁赢取决于启动顺序。

**解决**

二选一，不要同时启用：

```bash
systemctl is-enabled NetworkManager network    # 先看现状
```

```bash
# 方案一：统一用传统 network.service
systemctl disable --now NetworkManager
systemctl enable --now network

# 方案二：统一用 NetworkManager
systemctl disable --now network
systemctl enable --now NetworkManager
nmcli connection reload
nmcli connection up ens33
```

### 问题 4：只想重启单块网卡，不想动整个网络服务

**现象**

```text
Device 'ens33' does not seem to be present, delaying initialization.
```

**原因**

`ifup` / `ifdown` 读的是 `ifcfg-` 文件，网卡被 NetworkManager 接管后这两个脚本拿不到控制权，就当作设备不存在。

**解决**

```bash
ifdown ens33 && ifup ens33                                  # network 服务在管时
nmcli connection down ens33 && nmcli connection up ens33     # NetworkManager 在管时
```

---

## 三、脚本粘贴与文件写入相关

### 问题 1：Windows 上编辑过的脚本报 `$'\r': command not found`

**现象**

```text
/root/server_check.sh: line 2: $'\r': command not found
```

文件能 `cat` 出来，内容看着完全正常，但一执行就满屏这种报错。

**原因**

换行是 CRLF，`\r` 被当成行内容的一部分：跟在命令名后面就成了另一条不存在的命令，跟在参数后面就污染参数值，跟在 `]` 后面会让 `[` 报缺少 `]`。

**为什么 `bash -n` 能过**

`\r` 是合法字符，不是语法错误，只是被算进单词里，语法结构依然成立，错误只在执行到该行时才出现。所以语法检查通过不代表文件可用，两项检查要分开做：

```bash
bash -n server_check.sh                # 语法
grep -c $'\r' server_check.sh          # 换行，必须输出 0
file server_check.sh                   # 出现 "CRLF line terminators" 就是它
```

**解决**

```bash
sed -i 's/\r$//' server_check.sh

# 或
yum install -y dos2unix && dos2unix server_check.sh
```

**预防**

仓库根目录放 `.gitattributes`，让 Git 强制这类文件用 LF：

```text
*.sh text eol=lf
```

Windows 侧再配一次：

```bash
git config --global core.autocrlf input
```

已经用 `core.autocrlf=true` 克隆过的仓库，工作区里仍是 CRLF，光改配置不会自动修复，需要重新检出才能刷新工作区文件。

### 问题 2：heredoc 写文件的三条硬性要求

用 `cat > 文件 <<'EOF'` 在目标机上直接落盘，是内网环境最省事的方式，但三个细节错了就会写出一个「看起来对、跑起来不对」的文件。

**一、`<<'EOF'` 的引号不能省**

加了单引号，正文原样写入；不加，正文里的 `$变量`、`$(命令)`、反引号会在**写入时**就被展开。巡检脚本里有大量 `$(...)` 和 `awk '{...}'`，省掉引号等于先把脚本执行一半再把结果写进去。

**二、结束符必须顶格、独占一行**

前置空格会让 heredoc 一直不结束，后面的命令全被吞进文件。`<<-` 形式的缩进只对 TAB 有效，对空格无效。

**三、正文里不能出现单独一行的大写 `EOF`**

出现就提前结束，后面的内容会被当成 shell 命令执行。脚本自身包含 heredoc 时，换一个结束符名字：

```bash
cat > /root/server_check.sh <<'OUTER'
#!/bin/bash
cat > /tmp/inner.conf <<'INNER'
key=value
INNER
OUTER
```

**写完必查四项**

```bash
ls -l /root/server_check.sh            # 大小不为 0，权限带 x
wc -l /root/server_check.sh            # 和预期行数一致
head -1 /root/server_check.sh          # 必须是 #!/bin/bash
bash -n /root/server_check.sh && echo syntax_ok
```

改已有文件直接 `cat >` 覆盖，不要用 `>>` 追加；要留退路就先 `cp server_check.sh server_check.sh.bak`。

### 问题 3：BOM 与 GBK，两种不报语法错的编码坑

**BOM：`./xx.sh` 报 bad interpreter，`bash xx.sh` 却正常**

Windows 记事本存「UTF-8」会带 BOM，文件开头多出 `EF BB BF` 三个字节，`#!/bin/bash` 前面被塞了东西，内核找不到解释器：

```text
bash: ./server_check.sh: /bin/bash: bad interpreter: No such file or directory
```

这里容易误判成权限或路径问题——注意 `bash server_check.sh`（显式指定解释器、不走 shebang）反而是正常的，光凭这一点就能区分。

```bash
head -c 3 server_check.sh | xxd           # 开头是 efbbbf 就是 BOM
sed -i '1s/^\xEF\xBB\xBF//' server_check.sh
```

**GBK 与 locale**

GBK 保存的中文注释在 UTF-8 终端里显示成乱码，反过来也一样。bash 按字节处理注释，执行本身不受影响，但排查时连报错信息里的中文都看不懂：

```bash
echo $LANG
file -i server_check.sh
iconv -f GBK -t UTF-8 in.sh -o out.sh
```

当前脚本正文是纯 ASCII，不会踩这个坑；一旦加中文注释，统一存 UTF-8。脚本第 2 行的 `export LC_ALL=C` 是刻意为之：它让 `awk` / `sort` / `grep` 按字节处理，`awk` 的 `printf` 不会因为机器 locale 不同把小数点输出成逗号，`%-22s` 的列宽也按字节计算——代价是路径含中文时列会对不齐，属于用对齐换稳定性的取舍。

---

## 四、定时任务相关

### 问题 1：cron 的 PATH 比登录环境窄

**现象**

手动执行 `/root/server_check.sh` 一切正常，挂进 cron 后 `PORT` 段是空的，或者日志里出现 `command not found`。

**原因**

`crontab -e` 写的用户任务用的是 crond 自身的默认 PATH，通常只有 `/usr/bin:/bin`。`/etc/crontab` 顶部那行 `PATH=` 只对 `/etc/crontab` 和 `/etc/cron.d/` 里的任务生效，管不到用户 crontab。`ss` 装在 `/usr/sbin`，正好不在其中。

**解决**

脚本开头显式设置 PATH（本项目脚本第 3 行就是这么做的）：

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

自己写的脚本照抄这一行，或者在 crontab 里写绝对路径。

**排查**

让 cron 把自己的环境吐出来：

```cron
* * * * * env > /tmp/cron-env.txt
```

### 问题 2：重定向到不存在的目录，任务静默失败

**现象**

`crontab -l` 里任务在，到点了却没反应，`>>` 指向的日志文件一直不存在，也没有任何告警。

**原因**

`>>` 的目标目录不存在时，shell 连文件都打不开，整条命令根本不会执行。错误信息只进 cron 邮件，而最小化系统通常没装 MTA，于是错误被彻底吞掉。

**解决**

```bash
mkdir -p /var/log/server_check
```

也可以把输出交给 syslog，不依赖目录：

```cron
0 * * * * /root/server_check.sh 2>&1 | logger -t server_check
```

### 问题 3：直接往 `/var/spool/cron/root` 追加会粘连

**现象**

```bash
echo '0 * * * * /root/server_check.sh' >> /var/spool/cron/root
```

之后 `crontab -l` 里看不到这条任务，也不报错。

**原因**

原文件最后一行没有换行符时，追加的内容接在末尾，和上一行粘成一条非法记录，cron 解析失败后跳过它。

**解决**

用 `crontab -e`；脚本化添加时这样写：

```bash
(crontab -l 2>/dev/null; echo '0 * * * * /root/server_check.sh >> /var/log/server_check/cron.log 2>&1') | crontab -
```

**验证**

`crontab -l` 和 `tail -2 /var/spool/cron/root` 都看一遍，确认是两行而不是一行。

### 问题 4：巡检日志自己把磁盘撑满

**现象**

巡检脚本每小时往 `alert.log` 追加，几个月后触发磁盘告警的，很大一部分就是这份日志自己写进去的。

**原因**

脚本只负责追加，不负责轮转，日志文件无上限。

**解决**

交给 logrotate，配置见 [README.md](README.md) 的「使用步骤」第 6 步。注意巡检脚本要检查的磁盘，应该包括日志所在的分区。
