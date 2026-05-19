#!/bin/bash

osRelease=""

publicKey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETbOuKJEi5BUJXkCopshD/dfAKTOphKM9fqffCH5v+Y SMY"
nezhaServer="status.smy.me:443"

# SMY Root Certification Authority ECC
read -r -d '' ECC_Content << 'EOF'
-----BEGIN CERTIFICATE-----
MIICSDCCAc6gAwIBAgIUM4jeRFYbyv7wkCJ9C+j8hHpGECEwCgYIKoZIzj0EAwMw
WjELMAkGA1UEBhMCQ04xDjAMBgNVBAgMBUh1bmFuMQwwCgYDVQQKDANTTVkxLTAr
BgNVBAMMJFNNWSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzAgFw0y
MzEyMjEwNzUyNDVaGA8yMTIyMTEyNzA3NTI0NVowWjELMAkGA1UEBhMCQ04xDjAM
BgNVBAgMBUh1bmFuMQwwCgYDVQQKDANTTVkxLTArBgNVBAMMJFNNWSBSb290IENl
cnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzB2MBAGByqGSM49AgEGBSuBBAAiA2IA
BBvH4Xa36MTKrnhBIyyUg/IxykVOwZhzVXzYPswPGOYYE9enmuqmdaN6lhXzduBT
5arxSCULpsrZ8lb/wxO6cEkJCa5E1acfgVRdno6JfdBxZd7WEw8J94mrbqw5mxPr
Q6NTMFEwHQYDVR0OBBYEFD5c06VwJKNCtzLpVCcd6HS8RtrKMB8GA1UdIwQYMBaA
FD5c06VwJKNCtzLpVCcd6HS8RtrKMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0E
AwMDaAAwZQIwWOC+QllECy76guWZNdQSDXO5sSUlo1JBwQVTbwDrtF2ABB7ptjgh
9/ILrkbq7rM5AjEA7pXuwkLz/hZUQM/RtNAsMkzbxqBUOwrxV9LJ0sWF4uQjxMu8
aSsoBsICQmAdfnx+
-----END CERTIFICATE-----
EOF

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi

function  start_menu(){
    clear || true

    green " ================================================================="
    green " SMY One-click deployment script"
    green " Support: / Debian / Ubuntu / Openwrt / Alpine"
    green " ================================================================="
    green " System type：$osRelease"
    echo
    green " 1. Set the Time zone to UTC+8"
    green " 2. Configure SSH and Root accounts"
    green " 3. Set SSH port to 54422"
    green " 4. Install SMY Root Certification Authority"
    green " 5. Run Nezha-agent script"
    green " 6. Install Nginx"
    green " 7. Install Caddy"
    green " 8. Reboot system"
    green " 0. Exit script"

    echo
    read -p "Please input number:" menuNumberInput
    case "$menuNumberInput" in

        1 )
        #1. 设置北京时区
            echo "设置北京时区........"
            setLinuxDateZone

            back_to_menu
            
        ;;

        2 )
        #2. 配置SSH及Root账户 
            echo "Set SSH root login........"
            yellow "Please enter a new root password"
            passwd root
            green "Change root password successful！"
            echo "Import SSH public key........"
            setPublicKey
            green "Successful！, Please login to the server using SSH tool software!"
            
            back_to_menu

        ;;

        3 )
        #3. 修改 SSH 端口为 54422
            changeSshPort 0
            back_to_menu
        ;;

        4 )
        #4. 安装 SMY Root Certification Authority
            installCA
            echo "Please manually reboot to make the changes take effect"
            back_to_menu
        ;;

        5 )
        #5. 运行哪吒监控 Agent 安装脚本
            installNezha
            back_to_menu
        ;;

        6 )
        #6. 从 Nginx 源安装 Nginx Stable version
            
            # 根据不同的发行版，选择不同的安装方式
            case $osRelease in
                ubuntu)
                    # 对于Ubuntu系统
                    install_nginx_ubuntu
                    create_nginx_config
                    # Start and enable Nginx service
                    echo "Starting Nginx..."
                    systemctl start nginx
                    systemctl enable nginx
                    ;;
                debian)
                    # 对于Debian系统
                    install_nginx_debian
                    create_nginx_config
                    # Start and enable Nginx service
                    echo "Starting Nginx..."
                    systemctl start nginx
                    systemctl enable nginx
                    ;;
                centos)
                    # 对于CentOS系统
                    install_nginx_centos
                    create_nginx_config
                    # Start and enable Nginx service
                    echo "Starting Nginx..."
                    systemctl start nginx
                    systemctl enable nginx
                    ;;
                alpine)
                    # 对于Alpine系统
                    install_nginx_alpine
                    create_nginx_config
                    # Start and enable Nginx service
                    echo "Starting Nginx..."
                    rc-service nginx start
                    rc-update add nginx default
                    ;;
                *)
                    yellow "Unsupported Linux version: $osRelease"
                    ;;
            esac

            back_to_menu
        ;;

        7 )
        #7. 安装 Caddy
            install_caddy
            back_to_menu
        ;;

        8 )
        #8. 重启系统
            reboot
        ;;

        0 )
            exit 0
        ;;

        * )
            clear || true
            red "Please enter the option!"
            sleep 2s
            start_menu
        ;;
    esac

}

# fonts color
function red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
function green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
function blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
function bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}

# 检测系统发行版代号，返回centos,debian,ubuntu,alpine,openwrt,other
function getLinuxOSRelease(){
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|alpine|centos|openwrt)
                osRelease="$ID"
                ;;
            raspbian)
                osRelease="debian"
                ;;
            rhel|rocky|almalinux|fedora)
                osRelease="centos"
                ;;
            *)
                osRelease="other"
                ;;
        esac
    elif [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
    elif grep -Eqi "debian|raspbian" /etc/issue 2>/dev/null; then
        osRelease="debian"
    elif grep -Eqi "ubuntu" /etc/issue 2>/dev/null; then
        osRelease="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue 2>/dev/null; then
        osRelease="centos"
    elif grep -Eqi "alpine" /etc/issue 2>/dev/null; then
        osRelease="alpine"
    elif command -v opkg >/dev/null 2>&1; then
        osRelease="openwrt"
    else
        osRelease="other"
    fi
}

# 辅助函数：包管理与环境检查
function pkg_update(){
    case $osRelease in
        ubuntu|debian) apt-get update ;;
        centos) yum makecache ;;
        alpine) apk update ;;
        openwrt) opkg update ;;
    esac
}

function pkg_install(){
    case $osRelease in
        ubuntu|debian) apt-get install -y "$@" ;;
        centos) yum install -y "$@" ;;
        alpine) apk add "$@" ;;
        openwrt) opkg install "$@" ;;
    esac
}

function check_dependencies(){
    echo "Checking dependencies........"
    getLinuxOSRelease
    local deps=("curl" "wget" "tar" "openssl" "ca-certificates")
    
    # 确保包管理器可用并安装基础依赖
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Installing $dep..."
            pkg_install "$dep" || true
        fi
    done
}

function back_to_menu(){
    echo
    read -p "Return to the Menu? Enter to return to the Menu by Default, Please enter [Y/n]:" isContinueInput
    isContinueInput=${isContinueInput:-Y}

    if [[ ${isContinueInput:-Y} == [Yy] ]]; then
        start_menu
    else 
        exit 0
    fi
}


# 写入 SSH公钥
function setPublicKey(){

    if [ -d /etc/dropbear ]; then
        # dropbear
        
        echo "$publicKey" >> /etc/dropbear/authorized_keys
        chmod 700 /etc/dropbear
        chmod 600 /etc/dropbear/authorized_keys
        
        # 重启dropbear服务
        if command -v systemctl &>/dev/null; then
            systemctl restart dropbear
        elif command -v service &>/dev/null; then
            service dropbear restart
        fi

    elif [ -f /etc/ssh/sshd_config ]; then
        # sshd
        
        if [ ! -d "/root/ssh" ]; then
            mkdir -p /root/.ssh
        fi

        echo "$publicKey" > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys

        # 禁用SSH密码认证
        sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

        green "Disable SSH password authentication and successfully import SSH public key!"

        # 重启SSH服务
        if command -v systemctl &>/dev/null; then
            systemctl restart sshd
        elif command -v service &>/dev/null; then
            service ssh restart
        fi
    else
        yellow "SSH public key import failed, Unable to recognize SSH Server" 
    fi

}


# 设置北京时区
function setLinuxDateZone(){

    tempCurrentDateZone=$(date +'%z')

    echo
    if [[ ${tempCurrentDateZone} == "+0800" ]]; then
        yellow "The current Time-zone is already set to UTC+8 $tempCurrentDateZone | $(date -R) "
    else 

        if [[ -f /etc/localtime ]] && [[ -f /usr/share/zoneinfo/Asia/Shanghai ]];  then
            mv /etc/localtime /etc/localtime.bak
            cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

            yellow " The current time zone has been set to $(date -R)"
            green " =================================================="
        fi

    fi


}

# 修改ssh端口
function changeSshPort(){

    if [ -f /etc/default/dropbear ]; then
        # dropbear
        sed -i "/DROPBEAR_PORT/c\DROPBEAR_PORT=54422" /etc/default/dropbear
        sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=54422/" /etc/default/dropbear
        

        green "Successfully modified SSH port! The new port is 54422"

        if [ "${1:-0}" = 1 ]; then
            service dropbear restart
            echo "Restart SSH server"
        fi
    
    elif [ -f /etc/config/dropbear ]; then
        uci set dropbear.@dropbear[0].Port=54422
        uci commit dropbear
        green "Successfully modified SSH port! The new port is 54422"

        if [ "${1:-0}" = 1 ]; then
            /etc/init.d/dropbear restart
            echo "Restart SSH server"
        fi

    elif [ -f /etc/ssh/sshd_config ]; then
        # sshd

        sed -i "/^#Port .*/c\Port 54422" /etc/ssh/sshd_config
        sed -i "s/^Port .*/Port 54422/" /etc/ssh/sshd_config
        
        if [ "${1:-0}" = 1 ]; then
            systemctl restart sshd
            echo "Restart SSH server"
        fi
        green "Successfully modified SSH port! The new port is 54422"


    else
        yellow "SSH port modification failed, Unable to recognize SSH Server" 
    fi

}

# 安装CA
function installCA(){
    # 根据不同的发行版，执行不同的命令导入证书
    case $osRelease in
        ubuntu|debian)
            # 对于Ubuntu和Debian系统
            pkg_install ca-certificates
            echo "$ECC_Content" > "/usr/local/share/ca-certificates/SMY-Root-CA.crt"
            update-ca-certificates
            ;;
        centos)
            # 对于CentOS系统
            pkg_install ca-certificates
            echo "$ECC_Content" > "/etc/pki/ca-trust/source/anchors/SMY-Root-CA.crt"
            update-ca-trust extract
            ;;
        openwrt)
            # 对于OpenWrt系统
            echo "$ECC_Content" > "/etc/ssl/certs/SMY-Root-CA.crt"
            ;;
        *)
            yellow "Unsupported Linux version: $osRelease"
            ;;
    esac

    green "CA has been imported and updated"
    

}

# 安装哪吒 Agent
function installNezha(){
    local nezhaClientSecret="${1:-}"

    if [[ -z "$nezhaClientSecret" ]]; then
        read -p "Enter the Nezha Client Secret:" nezhaClientSecret
    fi

    if [[ -z "$nezhaClientSecret" ]]; then
        yellow "Client Secret is empty！"
        return 1
    fi

    echo "Installing Nezha-agent v2..."
    curl -L https://cdn.jsdelivr.net/gh/nezhahq/scripts@main/agent/install.sh -o nezha.sh
    chmod +x nezha.sh
    # 预制服务器地址及相关配置
    env NZ_SERVER="$nezhaServer" NZ_TLS=true NZ_CLIENT_SECRET="$nezhaClientSecret" NZ_DISABLE_COMMAND_EXECUTE=true ./nezha.sh
    rm -f nezha.sh
}

# Function to install Caddy for Ubuntu
install_caddy_ubuntu() {
    pkg_update
    pkg_install curl debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    pkg_update
    pkg_install caddy
}

# Function to install Caddy for Debian
install_caddy_debian() {
    pkg_update
    pkg_install curl debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    pkg_update
    pkg_install caddy
}

# Function to install Caddy for CentOS/RHEL
install_caddy_centos() {
    pkg_install yum-utils
    yum install -y 'dnf-command(copr)'
    yum copr enable -y @caddy/caddy
    pkg_install caddy
}

# Function to install Caddy for alpine
install_caddy_alpine() {
    pkg_update
    pkg_install caddy
}

install_caddy() {
    # 根据不同的发行版，选择不同的安装方式
    case $osRelease in
        ubuntu)
            install_caddy_ubuntu
            ;;
        debian)
            install_caddy_debian
            ;;
        centos)
            install_caddy_centos
            ;;
        alpine)
            install_caddy_alpine
            ;;
        *)
            yellow "Unsupported Linux version for Caddy: $osRelease"
            return 1
            ;;
    esac

    create_caddy_config

    # Start and enable Caddy service
    echo "Starting Caddy..."
    if command -v systemctl &>/dev/null; then
        systemctl enable caddy
        systemctl start caddy
    elif command -v rc-service &>/dev/null; then
        rc-update add caddy default
        rc-service caddy start
    fi
}

create_caddy_config() {
    local domainName=""
    read -p "Please enter your domain name (e.g., example.com):" domainName
    
    if [[ -z "$domainName" ]]; then
        red "Domain name cannot be empty!"
        return 1
    fi

    mkdir -p /usr/share/nginx/html
    mkdir -p /etc/caddy

    # download html
    if curl -fsSL -o html.tar.gz https://cdn.jsdelivr.net/gh/smy116/RootCA@main/nginx/html.tar.gz; then
        tar -zxvf html.tar.gz -C /usr/share/nginx/html
        rm -rf html.tar.gz
    else
        yellow "Failed to download HTML package, skipping..."
    fi

    # write Caddyfile
    cat > /etc/caddy/Caddyfile <<EOF
{
    admin off
}

http://$domainName {
    redir https://{host}{uri}
}

$domainName {
    root * /usr/share/nginx/html
    file_server
    encode gzip
    header {
        -Server
    }
}
EOF
}

# Function to install Nginx for Ubuntu
install_nginx_ubuntu() {
    pkg_update
    pkg_install curl gnupg2 ca-certificates lsb-release ubuntu-keyring
    echo "Adding Nginx repository for Ubuntu..."
    wget -qO- https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/ubuntu/ $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list
    pkg_update
    echo "Installing Nginx..."
    pkg_install nginx
}

# Function to install Nginx for Debian
install_nginx_debian() {
    pkg_update
    pkg_install curl gnupg2 ca-certificates lsb-release debian-archive-keyring
    echo "Adding Nginx repository for Debian..."
    wget -qO- https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian/ $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list
    pkg_update
    echo "Installing Nginx..."
    pkg_install nginx
}

# Function to install Nginx for CentOS/RHEL
install_nginx_centos() {
    pkg_install yum-utils
    echo "Adding Nginx repository for CentOS/RHEL..."
    cat > /etc/yum.repos.d/nginx.repo <<EOL
[nginx-stable]
name=nginx stable repository
baseurl=https://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOL
    echo "Installing Nginx..."
    pkg_install nginx
}


# Function to install Nginx for alpine
install_nginx_alpine() {
    pkg_update
    pkg_install openssl curl ca-certificates
    ALPINE_VERSION=$(cat /etc/alpine-release | cut -d '.' -f 1-2)
    echo "http://nginx.org/packages/alpine/v${ALPINE_VERSION}/main" >> /etc/apk/repositories
    curl -fsSL -o /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub
    mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/
    pkg_update
    pkg_install nginx
}

create_nginx_config() {
    mkdir -p /usr/share/nginx/acme-challenge
    mkdir -p /usr/share/nginx/html

    # download html
    if curl -fsSL -o html.tar.gz https://cdn.jsdelivr.net/gh/smy116/RootCA@main/nginx/html.tar.gz; then
        tar -zxvf html.tar.gz -C /usr/share/nginx/html
        rm -rf html.tar.gz
    else
        yellow "Failed to download HTML package, skipping..."
    fi
    
    # build dhparam.pem
    echo "Generating DHParam (2048-bit), this may take a minute..."
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

    # write config
    curl -fsSL -o /etc/nginx/nginx.conf https://cdn.jsdelivr.net/gh/smy116/RootCA@main/nginx/nginx.conf || yellow "Failed to download nginx.conf"
}

# 接收到的参数，选择要执行的操作
case "${1:-}" in
    ca)
        check_dependencies
        # 安装 SMY Root Certification Authority
        installCA
        exit 0
        ;;

    sshport)
        check_dependencies
        # 修改 SSH 端口为 54422
        changeSshPort 1
        exit 0
        ;;

    root)
        check_dependencies
        # 配置SSH及Root账户
            
        if [ -z "${2:-}" ]; then
            yellow "Error:Password empty"
            exit 1
        fi
        echo "root:$2" | chpasswd
        setPublicKey
        exit 0
        ;;

    nezha)
        check_dependencies
        # 安装哪吒 Agent
        if [ -z "${2:-}" ]; then
            yellow "Error: Nezha Client Secret is empty"
            exit 1
        fi
        installNezha "$2"
        exit 0
        ;;
    caddy)
        check_dependencies
        # 安装 Caddy
        install_caddy
        exit 0
        ;;
    *)
        check_dependencies
        start_menu
        ;;
esac
