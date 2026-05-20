# [qBittorrent](https://github.com/qbittorrent/qBittorrent), [WireGuard](https://www.wireguard.com) and [OpenVPN](https://openvpn.net)

**Forked from [DyonR/docker-qbittorrentvpn](https://github.com/DyonR/docker-qbittorrentvpn/)**

[![Docker Pulls](https://img.shields.io/docker/pulls/kronflux/qbittorrentvpn)](https://hub.docker.com/r/kronflux/qbittorrentvpn)
[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/kronflux/qbittorrentvpn/latest)](https://hub.docker.com/r/kronflux/qbittorrentvpn)

Docker container which runs the latest [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox client while connecting to WireGuard or OpenVPN with iptables killswitch to prevent IP leakage when the tunnel goes down.

[preview]: https://github.com/user-attachments/assets/e0630596-ff8b-4b17-aba5-4428ae38e181 "qBittorrent WebUI"
![alt text][preview]

# Docker Features
* Base: Debian trixie-slim
* [qBittorrent](https://github.com/qbittorrent/qBittorrent) compiled from source
* [libtorrent](https://github.com/arvidn/libtorrent) compiled from source
* Compiled with the latest version of [Boost](https://www.boost.org/)
* Compiled with the latest versions of [CMake](https://cmake.org/)
* Selectively enable or disable WireGuard or OpenVPN support
* IP tables killswitch to prevent IP leaking when VPN connection fails
* Configurable UID and GID for config files and /downloads for qBittorrent
* Created with [Unraid](https://unraid.net/) in mind
* BitTorrent port 8999 exposed by default

## Run container from Docker registry
The container is available from the Docker registry and this is the simplest way to get it  
To run the container use this command, with additional parameters, please refer to the Variables, Volumes, and Ports section:

```
$ docker run  -d \
              -v /your/config/path/:/config \
              -v /your/downloads/path/:/downloads \
              -e "VPN_ENABLED=yes" \
              -e "VPN_TYPE=wireguard" \
              -e "LAN_NETWORK=192.168.0.0/24" \
              -p 8080:8080 \
              --cap-add NET_ADMIN \
              --sysctl "net.ipv4.conf.all.src_valid_mark=1" \
              --restart unless-stopped \
              kronflux/qbittorrentvpn
```

# Variables, Volumes, and Ports
## Environment Variables
| Variable | Required | Function | Example | Default |
|----------|----------|----------|----------|----------|
|`VPN_ENABLED`| Yes | Enable VPN (yes/no)?|`VPN_ENABLED=yes`|`yes`|
|`VPN_TYPE`| Yes | WireGuard or OpenVPN (wireguard/openvpn)?|`VPN_TYPE=wireguard`|`openvpn`|
|`VPN_USERNAME`| No | If username and password provided, configures ovpn file automatically |`VPN_USERNAME=ad8f64c02a2de`||
|`VPN_PASSWORD`| No | If username and password provided, configures ovpn file automatically |`VPN_PASSWORD=ac98df79ed7fb`||
|`LAN_NETWORK`| Yes (atleast one) | Comma delimited local Network's with CIDR notation |`LAN_NETWORK=192.168.0.0/24,10.10.0.0/24`||
|`LEGACY_IPTABLES`| No | Use `iptables (legacy)` instead of `iptables (nf_tables)` |`LEGACY_IPTABLES=yes`||
|`ENABLE_SSL`| No | Let the container handle SSL (yes/no/ignore)? |`ENABLE_SSL=yes`|`ignore`|
|`NAME_SERVERS`| No | Comma delimited name servers (OpenVPN only; WireGuard uses `DNS=` in wg0.conf) |`NAME_SERVERS=1.1.1.1,1.0.0.1`|`1.1.1.1,1.0.0.1`|
|`PUID`| No | UID applied to /config files and /downloads |`PUID=99`|`99`|
|`PGID`| No | GID applied to /config files and /downloads  |`PGID=100`|`100`|
|`UMASK`| No | |`UMASK=002`|`002`|
|`HEALTH_CHECK_HOST`| No |Host or IP used for connectivity checks. The runtime health loop defaults to `one.one.one.one` (also validates DNS). The Docker HEALTHCHECK directive defaults to `1.1.1.1` (raw IP, no DNS required).|`HEALTH_CHECK_HOST=1.1.1.1`|`one.one.one.one` / `1.1.1.1`|
|`HEALTH_CHECK_INTERVAL`| No |This is the time in seconds that the container waits to see if the internet connection still works (check if VPN died)|`HEALTH_CHECK_INTERVAL=300`|`60`|
|`HEALTH_CHECK_SILENT`| No |Set to `1` to supress the 'Network is up' message. Defaults to `1` if unset.|`HEALTH_CHECK_SILENT=1`|`1`|
|`HEALTH_CHECK_AMOUNT`| No |The amount of pings that get send when checking for connection.|`HEALTH_CHECK_AMOUNT=10`|`1`|
|`HEALTH_CHECK_FAILURE_THRESHOLD`| No |Number of *consecutive* failed health checks before the container restarts. Prevents a single transient packet loss event from killing the container. Reset to 0 on any successful check.|`HEALTH_CHECK_FAILURE_THRESHOLD=5`|`3`|
|`RESTART_CONTAINER`| No |Set to `no` to **disable** the automatic restart when the network is possibly down.|`RESTART_CONTAINER=yes`|`yes`|
|`VPN_WAIT_TIMEOUT`| No |Seconds to wait for VPN tunnel to come up before exiting with an error.|`VPN_WAIT_TIMEOUT=120`|`120`|
|`WEBUI_PORT`| No |Port for the qBittorrent WebUI. Must match the container port mapping.|`WEBUI_PORT=8080`|`8080`|
|`ENABLE_UPNP`| No |Enable UPnP port mapping in qBittorrent. Disabled by default — UPnP is ineffective and potentially leaky behind a VPN.|`ENABLE_UPNP=yes`|`no`|
|`WEBUI_USERNAME`| No | WebUI username. Only applied when `WEBUI_PASSWORD` is also set. |`WEBUI_USERNAME=admin`|`admin`|
|`WEBUI_PASSWORD`| No | WebUI password in plain text. When set, the container hashes it with PBKDF2-SHA512 and writes it into qBittorrent's config on every start, overriding any existing password. Useful for initial provisioning or password recovery. Leave unset to let qBittorrent generate a one-time password on first launch (logged to `/config/qBittorrent/data/logs/qbittorrent.log`).|`WEBUI_PASSWORD=changeme`||
|`ADDITIONAL_PORTS`| No |Adding a comma delimited list of ports will allow these ports via the iptables script.|`ADDITIONAL_PORTS=1234,8112`||
|`SKIP_CHOWN_DOWNLOADS`| No | Skips taking ownership(chown) of the downloads path at startup.|`SKIP_CHOWN_DOWNLOADS="yes"`|`no`|

## Volumes
| Volume | Required | Function | Example |
|----------|----------|----------|----------|
| `config` | Yes | qBittorrent, WireGuard and OpenVPN config files | `/your/config/path/:/config`|
| `downloads` | No | Default downloads path for saving downloads | `/your/downloads/path/:/downloads`|

## Ports
| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `8080` | TCP | Yes | qBittorrent WebUI | `8080:8080`|
| `8999` | TCP | Yes | qBittorrent TCP Listening Port | `8999:8999`|
| `8999` | UDP | Yes | qBittorrent UDP Listening Port | `8999:8999/udp`|

# Access the WebUI
Access https://IPADDRESS:PORT from a browser on the same network. (for example: https://192.168.0.90:8080)

## WebUI Credentials

Starting with qBittorrent 4.6, the hardcoded `admin`/`adminadmin` default was removed. There are now two ways to log in on first launch:

**Option 1 — Set a password via environment variable (recommended for automated setups):**
Set `WEBUI_PASSWORD` (and optionally `WEBUI_USERNAME`, defaults to `admin`). The container hashes it with PBKDF2-SHA512 and writes it into qBittorrent's config on startup. Re-applied on every restart, so changing the env var changes the password.

**Option 2 — Use the auto-generated temporary password:**
Leave `WEBUI_PASSWORD` unset. On first launch qBittorrent generates a random temporary password and writes it to its own log. Find it with:

```
docker exec <container> grep -i "temporary password" /config/qBittorrent/data/logs/qbittorrent.log
```

Username is `admin`. After logging in, set a permanent password via **Tools → Options → Web UI → Authentication**.

# How to use WireGuard 
The container will fail to boot if `VPN_ENABLED` is set and there is no valid .conf file present in the /config/wireguard directory. Drop a .conf file from your VPN provider into /config/wireguard and start the container again. The file must have the name `wg0.conf`, or it will fail to start.

## WireGuard IPv6
If your WireGuard config contains IPv6 addresses (in `Address` or `AllowedIPs`), the container automatically enables IPv6 in its network namespace via sysctl — no `--sysctl` flag required on the docker run command.

If you have an IPv6 LAN you want to reach from inside the container, add it to `LAN_NETWORK`:
```
LAN_NETWORK=192.168.1.0/24,fd00::/8
```

# How to use OpenVPN
The container will fail to boot if `VPN_ENABLED` is set and there is no valid .ovpn file present in the /config/openvpn directory. Drop a .ovpn file from your VPN provider into /config/openvpn (if necessary with additional files like certificates) and start the container again. You may need to edit the ovpn configuration file to load your VPN credentials from a file by setting `auth-user-pass`.

**Note:** The script will use the first ovpn file it finds in the /config/openvpn directory. Adding multiple ovpn files will not start multiple VPN connections.

## Example auth-user-pass option for .ovpn files
`auth-user-pass credentials.conf`

## Example credentials.conf
```
username
password
```

## PUID/PGID
User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:

```
id <username>
```

# Issues
If you are having issues with this container please submit an issue on GitHub.  
Please provide logs, Docker version and other information that can simplify reproducing the issue.  
If possible, always use the most up to date version of Docker, you operating system, kernel and the container itself. Support is always a best-effort basis.

### Credits:
[DyonR/docker-qbittorrentvpn](https://github.com/DyonR/docker-qbittorrentvpn)
[MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
[DyonR/jackettvpn](https://github.com/DyonR/jackettvpn)  
This projects originates from MarkusMcNugen/docker-qBittorrentvpn, but forking was not possible since DyonR/jackettvpn uses the fork already.
