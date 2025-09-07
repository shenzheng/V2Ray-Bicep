---
description: '在Azure环境下，生成支持V2Ray的VM资源'
---
你的目的是生成一个包含V2Ray容器的VM，以 bicep形式表示，可以在Azure的资源组中创建VM。

这个VM需要实现以下需求：
* VM的规格可以指定，默认是Standard B2s
* VM需要打开443端口，VM可选打开22端口
* 操作系统为Linux (ubuntu 22.04)，x64架构
* VM需要有dns别名，该名称可指定
* VM启动后，需要执行以下操作
    * 安装docker
    * 能够加载镜像ghcr.io/li-yanzhi/connectworld2:latest（默认值），该参数可执行
    * 为该容器加载卷，映射到容器内目录'/root/.local/'，此目录在运行时，需要可以由容器去写，放置证书
    * 容器需要暴露的端口为443
    * 容器启动的命令如下：
    command: ["v2ray-vm.japaneast.cloudapp.azure.com", "V2RAY_WS", "2F15E03B-075E-460E-A27C-93ED282431BD"]

希望输出相关biceo，以及验证和排错手段