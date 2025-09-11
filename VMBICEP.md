本文档介绍本项目中使用的 Bicep 模板，其作用是自动化部署一台运行 V2Ray 容器的 Azure 虚拟机，并配置相关的网络、安全和启动脚本。

📌 Bicep 基础概念
	•	Bicep 是 Azure Resource Manager (ARM) 模板的简化声明式语法。
	•	它的主要特点是：可读性强、支持参数化、模块化、自动转译成 ARM JSON 模板。
	•	在本模板中，主要分为以下部分：
	•	参数 (param)
	•	变量 (var)
	•	资源 (resource)
	•	输出 (output)

🧩 模板主要组成部分

1. 参数定义 (param)

用于在部署时传入或设置默认值。
示例：

```bicep
@description('Virtual machine name.') q
param vmName string = 'v2ray-vm'
```

这里定义了 VM 名称，默认是 v2ray-vm。
其他关键参数：
	•	location：资源部署区域，默认和资源组相同。
	•	vmSize：虚拟机规格，默认 Standard_B2s。
	•	sshPublicKey：管理员 SSH 公钥（必须提供）。
	•	allowSsh：是否开放 22 端口。
	•	dnsLabel：公网 IP 的 DNS 前缀。
	•	containerImage / containerArgs：运行的容器镜像和参数。
	•	vnetCidr / subnetCidr：虚拟网络地址空间。

2. 变量定义 (var)

用于生成动态名称或组合参数，减少硬编码。
示例：

```bicep
var nsgName = '${vmName}-nsg'
var fqdnValue = pip.properties.dnsSettings.fqdn

	•	通过字符串插值生成资源名称。
	•	fqdnValue 用于拼接容器启动参数。
```

3. 资源声明 (resource)

真正要创建的 Azure 资源。

主要资源：
- Public IP (pip)：创建带静态 IP 和 DNS 的公网地址。
- NSG (nsg)：网络安全组，规则包括：
- 允许 443 入站（V2Ray 服务）。
- 可选允许 22 入站（SSH）。
- 显式拒绝所有其他入站。
- VNet + Subnet (vnet)：虚拟网络与子网，绑定 NSG。
- NIC (nic)：网络接口，绑定 Public IP 和 Subnet。
- VM (vm)：Ubuntu 22.04 LTS 虚拟机，附带 OS 磁盘和 NIC。
- VM Extension (ext)：使用 CustomScript：
  1.	安装 Docker 官方源和 Docker CE。
  2.	创建目录 /var/lib/v2ray-local。
  3.	写入 systemd unit 文件 v2ray-container.service。
  4.	启动容器并设置开机自启。
- systemd 单元文件

模板中自动生成的内容，确保 V2Ray 容器以 systemd 方式管理：

```init
[Unit]
Description=V2Ray container (Docker)
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5s
ExecStartPre=-/usr/bin/docker rm -f v2ray
ExecStart=/usr/bin/docker run --name v2ray --pull=always --restart=unless-stopped -p 443:443 -v /var/lib/v2ray-local:/root/.local {镜像} {参数}
ExecStop=/usr/bin/docker stop v2ray

[Install]
WantedBy=multi-user.target
```

5. 输出 (output)

部署完成后返回关键信息：
- publicIp：虚拟机公网 IP。
- fqdn：DNS 域名。
- dockerRunExample：本地调试用的 docker run 示例命令。
- sshHint：是否允许 SSH 登录的提示。

⚙️ 工作原理总结
1. 网络层
- 创建 VNet/Subnet/NSG。
- 配置安全组规则，只放行 HTTPS (443) 和可选 SSH (22)。
2. 计算层
- 创建 Ubuntu 22.04 LTS VM。
- 使用 SSH 公钥登录，无密码。
3. 自动化配置
- VM Extension 自动安装 Docker。
- 写入 systemd 单元，确保容器在系统启动时自动运行。
4. 容器运行
- 运行指定镜像 containerImage。
- 容器参数由 VM FQDN + containerArgs 拼接而成。
- 使用 -v /var/lib/v2ray-local:/root/.local 持久化配置。

📒 使用要点
	- 安全：
	- allowSsh=false 时，外部无法直接 SSH 登录。
	- 建议生产环境默认关闭 SSH，仅在调试时开启。
	- 可维护性：
	- osDiskName 使用 uniqueString 避免旧盘冲突。
	- 容器运行由 systemd 管理，支持自动重启。
	- 扩展性：
	- 可以更换 containerImage，无需修改核心逻辑。
	- 可以通过修改 NSG 增加额外端口。

✅ 总结

该 Bicep 模板实现了 一键部署 V2Ray VM：
- 自动化配置网络、安全组、Docker、systemd。
- 部署完成即可通过 443 端口使用。
- 可扩展、易维护、符合最小权限原则。
