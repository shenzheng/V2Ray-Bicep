Caddy.sh说明

代码位置

https://github.com/Li-Yanzhi/ConnectWorld/blob/v2/caddy.sh

---

## 🌟 **整体作用**

这是一个容器里运行时的启动脚本，主要做三件事：

✅ **根据传入参数动态生成配置文件**：

* Caddy 的 `/etc/Caddyfile`
* V2Ray 的 `/etc/fly.json`
* 一个前端用的配置文件 `/srv/sebs.js`

✅ **启动 Caddy**（Web 服务 + 反代 WebSocket）
✅ **启动 V2Ray**（vmess over websocket）

---

## 🏗 **脚本分段讲解**

### 1️⃣ 读取启动参数

```bash
domain="$1"
psname="$2"
uuid="51be9a06-299f-43b9-b713-1ec5eb76e3d7"

if  [ ! "$3" ] ;then
    uuid=$(uuidgen)
    echo "uuid 将会系统随机生成"
else
    uuid="$3"
fi
```

* `$1`：第一个参数是 **域名**（用来生成 Caddy 配置、v2ray 配置）。
* `$2`：第二个参数是 **ps 名称**（就是 v2ray 客户端配置里备注显示用）。
* `$3`：第三个参数如果有，就用作 uuid，否则随机生成一个新的 uuid。

---

### 2️⃣ 生成 Caddy 配置

```bash
cat > /etc/Caddyfile <<'EOF'
{
  admin off
}

domain:443 {
  encode gzip zstd
  root * /srv/www
  file_server
  @websockets {
    path /one
    header Connection Upgrade
    header Upgrade websocket
  }
  reverse_proxy @websockets 127.0.0.1:2333
}
EOF

sed -i "s/domain/${domain}/" /etc/Caddyfile
```

🔧 **内容含义：**

* 在 443 端口监听传入的 `domain` 域名
* 提供 `/srv/www` 下的静态文件（首页、静态资源）
* 对路径 `/one` 且具备 `Upgrade: websocket` 的请求，反代到 `127.0.0.1:2333`（V2Ray 的监听端口）
* 启用 gzip/zstd 压缩

`sed` 会把模板里的 `domain` 占位符替换成实际域名。

---

### 3️⃣ 生成 V2Ray 配置

```bash
cat > /etc/fly.json <<'EOF'
{
  "log": {
     "loglevel": "error"
  },
  "inbounds": [
    {
      "port": 2333,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "uuid",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/one"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

sed -i "s/uuid/${uuid}/" /etc/fly.json
```

🔧 **内容含义：**

* V2Ray 在 `2333` 端口监听 VMess 协议
* 使用 WebSocket 作为传输，路径 `/one`
* 客户端 id（uuid）是之前传入或随机生成的
* 出站用 `freedom`，即直接放行

`sed` 替换 `uuid` 占位符。

---

### 4️⃣ 生成客户端 JSON 配置 (sebs.js)

```bash
cat > /srv/sebs.js <<'EOF'
 {
    "add":"domain",
    "aid":"0",
    "host":"",
    "id":"uuid",
    "net":"ws",
    "path":"/one",
    "port":"443",
    "ps":"sebsclub",
    "tls":"tls",
    "type":"none",
    "v":"2"
  }
EOF
```

🔧 **内容含义：**

* 这是生成给 **v2rayN 等客户端导入** 的一段 JSON：

  * `add`：服务器域名
  * `port`：443
  * `id`：uuid
  * `net`：ws
  * `tls`：tls
  * `path`：/one
  * `ps`：备注名（默认 sebsclub）
* 下面这个 if 判断，会把模板里的 `domain`、`sebsclub`、`uuid` 替换为实际值。

```bash
if [ "$psname" != "" ] && [ "$psname" != "-c" ]; then
  sed -i "s/sebsclub/${psname}/" /srv/sebs.js
  sed -i "s/domain/${domain}/" /srv/sebs.js
  sed -i "s/uuid/${uuid}/" /srv/sebs.js
else
  $*
fi
```

⚠️ 这里还兼容了一个特殊情况：如果 `$2` 是空或者是 `-c`，就执行 `$*`（可能是调试用）。

---

### 5️⃣ 打印配置并启动 Caddy

```bash
echo "------- Caddy 配置 -------"
cat /etc/Caddyfile
echo "-------------"

echo "Run Caddy"
/usr/bin/caddy fmt --overwrite /etc/Caddyfile
nohup /usr/bin/caddy run --config /etc/Caddyfile &
```

* 打印出 Caddy 配置内容（方便调试）
* 格式化 Caddyfile
* 后台启动 Caddy

---

### 6️⃣ 打印 V2Ray 配置、运行 Node 脚本、启动 V2Ray

```bash
echo "------- Fly 配置 -------"
cat /etc/fly.json
echo "-------------"
node connect.js

echo "Run Fly"
/usr/bin/v2ray run -config /etc/fly.json
```

* 打印 V2Ray 配置（方便调试）
* 执行 `connect.js`（可能是一些初始化动作，例如把 sebs.js 推送给某个服务）
* 前台启动 V2Ray，用生成的 `/etc/fly.json` 配置。

---

## ✨ **整体流程图**

```
启动容器 -> 运行 caddy.sh
   ↓
读取参数 domain psname uuid
   ↓
生成 /etc/Caddyfile (Caddy配置)
生成 /etc/fly.json (V2Ray配置)
生成 /srv/sebs.js (客户端配置)
   ↓
打印配置
   ↓
后台运行 Caddy
   ↓
运行 Node 脚本 connect.js
   ↓
前台运行 V2Ray
```

---

## 💡 **总结**

| 功能          | 作用                        |
| ----------- | ------------------------- |
| 参数读取        | `$1=域名` `$2=备注` `$3=uuid` |
| 生成 Caddy 配置 | 监听443，反代 /one 到 V2Ray     |
| 生成 V2Ray 配置 | 启动 VMess on WebSocket     |
| 生成客户端配置     | 给 v2rayN 导入用              |
| 启动服务        | 后台启动 Caddy，前台启动 V2Ray     |

---

✅ **如果你想要我继续提供：**

* `connect.js` 里面可能做什么（可以给我内容我来解析）
* 如何在 Azure 容器实例用这个镜像和脚本启动
* 或者如何修改脚本让它支持多用户、多域名

直接告诉我！ 🚀🔥🛠️
