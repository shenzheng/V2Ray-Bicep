Dockerfile说明

代码位置

https://github.com/Li-Yanzhi/ConnectWorld/blob/v2/Dockerfile

---

## 🌟 **整体作用**

> 这个 Dockerfile 基于 `alpine:latest` 构建，
> 最终产出一个镜像，里面包含：
>
> * **Caddy**（作为 Web 服务器和反代）
> * **V2Ray**（作为代理内核）
> * **Node.js 环境**（跑 `connect.js` 这种脚本）
> * 一个 `index.html` 首页和静态资源
> * 一个挂载卷 `/root/.local`（用于证书或配置持久化）
>
> 启动容器时会执行 `/caddy.sh` 作为入口，暴露 443 端口。

---

## 🏗 **分段详解**

### ① 基础镜像 & 时区设置

```dockerfile
FROM alpine:latest

ARG TZ="Asia/Shanghai"
ENV TZ ${TZ}
```

* 选用体积很小的 Alpine 作为基础镜像。
* 定义 `TZ` 构建参数和环境变量，默认 `Asia/Shanghai`，用于时区配置。

---

### ② 安装 Caddy

```dockerfile
RUN apk upgrade --update \
    && apk add \
        bash \
        tzdata \
        curl \
    && version=$(curl -s https://api.github.com/repos/caddyserver/caddy/releases/latest | grep 'tag_name' | cut -d '"' -f 4 | sed 's/v//') \
    && echo "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_linux_amd64.tar.gz" \
    && curl -sSL "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_linux_amd64.tar.gz" | tar -xz -C /usr/bin caddy \
    && chmod +x /usr/bin/caddy \
    && /usr/bin/caddy -v \
    && echo ${version} > /tmp/caddy_version
```

👉 **做了什么：**

1. 安装 bash、时区数据、curl 等工具。
2. 通过 GitHub API 获取 **Caddy 最新版本号**。
3. 下载对应的 Caddy 二进制 tar 包，解压到 `/usr/bin/caddy`。
4. 给 Caddy 可执行权限，并运行 `caddy -v` 打印版本。
5. 把版本号写到 `/tmp/caddy_version`，后面插入 HTML 用。

---

### ③ 安装 V2Ray

```dockerfile
RUN version=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep 'tag_name' | cut -d '"' -f 4) \
    && wget -O - "https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip" | unzip -p - v2ray > /usr/bin/v2ray \
    && chmod +x /usr/bin/v2ray \
    && apk del curl \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && echo ${version} > /tmp/v2ray_version
```

👉 **做了什么：**

1. 通过 GitHub API 获取 V2Ray 最新版本。
2. 下载 zip 包，解压出 `v2ray` 可执行文件到 `/usr/bin/v2ray`。
3. 赋予可执行权限。
4. 删除 curl（清理不必要包，减小镜像体积）。
5. 配置时区软链接 `/etc/localtime`，写入 `/etc/timezone`。
6. 把 V2Ray 版本写到 `/tmp/v2ray_version`。

---

### ④ 工作目录和 Node.js 环境

```dockerfile
WORKDIR /srv

RUN apk add --no-cache util-linux
RUN apk add --no-cache --update nodejs npm
COPY package.json /srv/package.json
RUN npm install
COPY connect.js /srv/connect.js
```

👉 **做了什么：**

1. 工作目录设置为 `/srv`。
2. 安装 `util-linux`（提供一些常用命令），安装 Node.js 和 npm。
3. 拷贝 `package.json` 后执行 `npm install` 安装依赖。
4. 拷贝 `connect.js` 到 `/srv`，后续容器里可以执行它。

---

### ⑤ 挂载卷

```dockerfile
VOLUME /root/.local
```

👉 **作用：**

* 定义一个挂载卷，通常用来存放 Caddy 的自动 TLS 证书、配置等需要持久化的数据。
* 容器重建时，这个路径的数据可以挂载到外部保持不丢失。

---

### ⑥ 拷贝首页文件

```dockerfile
COPY index.html /srv/www/index.html
COPY dist/earth.min.js /srv/www/dist/earth.min.js
```

👉 **作用：**

* 把前端静态资源（首页和 JS 文件）放到 `/srv/www` 下，由 Caddy 提供静态服务。

---

### ⑦ 在 HTML 里插入构建信息

```dockerfile
RUN caddy_version=$(cat /tmp/caddy_version) \
    && v2ray_version=$(cat /tmp/v2ray_version) \
    && build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    && sed -i "s|<!--CADDY_VERSION-->|<meta name='c-version' content='$caddy_version'>|g" /srv/www/index.html \
    && sed -i "s|<!--V2RAY_VERSION-->|<meta name='v-version' content='$v2ray_version'>|g" /srv/www/index.html \
    && sed -i "s|<!--BUILD_TIMESTAMP-->|<meta name='build-time' content='$build_time'>|g" /srv/www/index.html
```

👉 **作用：**

* 读取 Caddy、V2Ray 版本以及当前 UTC 构建时间
* 用 `sed` 替换 `index.html` 中的占位符
* 最终生成的页面里会带 `<meta>` 标签，显示构建时用到的版本和时间。

---

### ⑧ 启动脚本和暴露端口

```dockerfile
ADD caddy.sh /caddy.sh

EXPOSE 443
ENTRYPOINT ["/caddy.sh"]
```

👉 **作用：**

* 拷贝 `caddy.sh` 到容器根目录，作为启动入口脚本。
* 暴露 443 端口给外部访问。
* 启动容器时，执行 `/caddy.sh`（一般里面会启动 Caddy 和 V2Ray）。

---

## ✨ **总结**

| 功能        | 对应段落                            |
| --------- | ------------------------------- |
| 基础镜像 & 时区 | `FROM alpine`、`ARG TZ`、`ENV TZ` |
| 安装 Caddy  | 通过 GitHub API 动态下载最新版           |
| 安装 V2Ray  | 同样用 GitHub API 获取最新版            |
| Node 环境   | 安装 nodejs/npm，拷贝并安装依赖           |
| 挂载卷       | `/root/.local` 用于证书等持久化         |
| 静态资源      | 拷贝 index.html 和 earth.min.js    |
| 构建信息      | 用 sed 把版本和时间写入 HTML             |
| 入口 & 端口   | `caddy.sh` 启动，暴露 443            |

---

## 💡 **这个镜像的特点**

✅ **体积小**：基于 Alpine
✅ **自动获取最新版本**：Caddy 和 V2Ray 都用 GitHub API 动态下载
✅ **自动插入版本信息**：方便前端页面显示
✅ **挂载卷存证书**：适合运行 Caddy 自动 HTTPS
✅ **多进程**：通常 caddy.sh 会同时启动 Caddy 和 V2Ray

---

如果你想，我可以帮你继续：
✅ 给出 `caddy.sh` 的示例
✅ 给出如何在 Azure ACI 运行这个镜像并挂载 `/root/.local`
✅ 或者改造成多阶段构建、优化体积

需要的话直接告诉我！ 🚀🔥🛠️
