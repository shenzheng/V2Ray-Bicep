#!/bin/bash
# FILE="/etc/Caddy"
domain="$1"
psname="$2"
uuid="51be9a06-299f-43b9-b713-1ec5eb76e3d7"
if  [ ! "$3" ] ;then
    uuid=$(uuidgen)
    echo "uuid 将会系统随机生成"
else
    uuid="$3"
fi

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


# v2ray
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

if [ "$psname" != "" ] && [ "$psname" != "-c" ]; then
  sed -i "s/sebsclub/${psname}/" /srv/sebs.js
  sed -i "s/domain/${domain}/" /srv/sebs.js
  sed -i "s/uuid/${uuid}/" /srv/sebs.js
else
  $*
fi

echo "------- Caddy 配置 -------"
cat /etc/Caddyfile
echo "-------------"

echo "Run Caddy"
/usr/bin/caddy fmt --overwrite /etc/Caddyfile
nohup /usr/bin/caddy run --config /etc/Caddyfile &

echo "------- Fly 配置 -------"
cat /etc/fly.json
echo "-------------"
node connect.js

echo "Run Fly"
/usr/bin/v2ray run -config /etc/fly.json
