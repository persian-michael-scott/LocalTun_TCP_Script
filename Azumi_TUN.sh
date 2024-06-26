#!/bin/bash


# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[36m'
NC='\033[0m' # No Color

# Set the owner and repo variables
OWNER="Azumi67"
REPO="LocalTun_TCP"

# Determine the architecture and set the ASSET_NAME accordingly
ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ]; then
  ASSET_NAME="arm64.zip"
elif [ "$ARCH" == "x86_64" ]; then
  ASSET_NAME="amd64.zip"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

arch_name="${ASSET_NAME%.*}"


# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Fetch server country using ip-api.com
SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

# Function to display server location and IP
display_server_info() {
    echo -e "${GREEN}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${GREEN}Server IP:${NC} $SERVER_IP"
}

# Function to download and unzip the release
download_and_unzip() {
  local url="$1"
  local dest="$2"

  echo "Downloading $dest from $url..."
  wget -q -O "$dest" "$url"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to download file."
    return 1
  fi

  echo "Unzipping $dest..."
  unzip -o "$dest"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to unzip file."
    return 1
  fi

  echo "Download and unzip completed successfully."
}

# Function to get download URL for the latest release
get_latest_release_url() {
  local api_url="https://api.github.com/repos/$OWNER/$REPO/releases/latest"

  echo "Fetching latest release data..." >&2
  local response=$(curl -s "$api_url")
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data." >&2
    return 1
  fi

  local asset_url=$(echo "$response" | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found." >&2
    return 1
  fi

  echo "$asset_url"
}

# Function to get download URL for a specific release version
get_specific_release_url() {
  local version=$1
  local api_url="https://api.github.com/repos/$OWNER/$REPO/releases/tags/$version"

  echo "Fetching release data for version $version..." >&2
  response=$(curl -s $api_url)
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data for version $version." >&2
    exit 1
  fi

  local asset_url=$(echo $response | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found for version $version." >&2
    exit 1
  fi

  echo $asset_url
}

install() {
    mkdir /root/localTUN
    cd /root/localTUN
    apt install wget -y
    apt install unzip -y
    apt install jq -y

    read -p "Do you want to install the latest version of Azumi LocalTun_TCP ? (y/n): " answer
    if [[ "$answer" == [Yy]* ]]; then
        # Get the latest release URL
        url=$(get_latest_release_url)

        if [ $? -ne 0 ] || [ -z "$url" ]; then
            echo "Failed to retrieve the latest release URL."
            exit 1
        fi
        echo "Latest Release URL: $url"
        download_and_unzip "$url" "$ASSET_NAME"
        if [ $? -ne 0 ]; then
            echo "Failed to download or unzip the file."
            exit 1
        fi
    elif [[ "$answer" == [Nn]* ]]; then
        read -p "Enter the version you want to install (e.g., v1.18): " version
        # Get the specific release URL
        url=$(get_specific_release_url "$version")

        if [ $? -ne 0 ] || [ -z "$url" ]; then
            echo "Failed to retrieve the latest release URL."
            exit 1
        fi
        echo "Specific Version URL: $url"
        download_and_unzip "$url" "$ASSET_NAME"
    else
        echo "Please answer yes (y) or no (n)."
        exit 1
    fi

    rm "$ASSET_NAME"
    chmod +x tun-server_$arch_name tun-client_$arch_name
}


setup_service() {
    local file_name="$1"
    local arg="$2"
    cat > /etc/systemd/system/azumilocal.service << EOF
[Unit]
Description=Azumi local Service
After=network.target

[Service]
Type=simple
Restart=always    
LimitNOFILE=1048576
ExecStart=/root/localTUN/$file $arg

[Install]
WantedBy=multi-user.target
EOF
    chmod u+x /etc/systemd/system/azumilocal.service
    systemctl daemon-reload
    systemctl enable /etc/systemd/system/azumilocal.service
    systemctl start azumilocal.service
}

check_status() {
    # Check if the normal_tunnel service is running
    if sudo systemctl is-active --quiet azumilocal.service; then
        echo -e "${YELLOW}Azumi local service status:${GREEN}    [running ✔ ]${NC}"
    else
        echo -e "${YELLOW}Azumi local service status:${RED}    [Not running ✗ ]${NC}"
    fi
}

check_installed() {
    if [ -f "/etc/systemd/system/azumilocal.service" ]; then
        echo "The service is already installed."
        exit 1
    fi
}


Forward_Tun() {
    check_installed
    install
    read -p "Which server are you currently on? (Enter '1' for Iran or '2' for Kharej ) : " option
    case $option in
        1)
            file="tun-client_$arch_name"
            read -p "Enter Kharej IPv4 ) : " KHAREJ_IPV4
            arguments="-server-addr $KHAREJ_IPV4 -server-port 800 -client-private 30.0.0.2 -server-private 30.0.0.1 -subnet 24 -device tun2 -key azumi -mtu 1400 -verbose true -smux true -heartbeat false -tcp-nodelay true -ping-interval 20 -service-name azumilocal"
            setup_service "$file" "$arguments"
            echo -e "${GREEN}Local IPv4 Kharej 30.0.0.1${NC}"
            echo -e "${BLUE}Local IPv4 Iran 30.0.0.2${NC}"
            ;;
        2)
            file="tun-server_$arch_name"
            arguments="-server-port 800 -server-private 30.0.0.1 -client-private 30.0.0.2 -subnet 24 -device tun2 -key azumi -mtu 1480 -verbose true -smux true -heartbeat false -tcp-nodelay true -ping-interval 20 -service-name azumilocal"
            setup_service "$file" "$arguments"
            echo -e "${GREEN}Local IPv4 Kharej 30.0.0.1${NC}"
            echo -e "${BLUE}Local IPv4 Iran 30.0.0.2${NC}"
            ;;
        *) echo -e "${RED}Invalid option!${NC}" && exit ;;
    esac

    echo ''
    read -p "Press Enter to continue..."
}

Reverse_Tun() {
    check_installed
    install
    read -p "Which server are you currently on? (Enter '1' for Iran or '2' for Kharej ) : " option
    case $option in
        1)
            file="tun-server_$arch_name"
            arguments="-server-port 800 -server-private 30.0.0.1 -client-private 30.0.0.2 -subnet 24 -device tun2 -key azumi -mtu 1480 -verbose true -smux true -tcp-nodelay true -heartbeat false -ping-interval 10 -service-name azumilocal"
            setup_service "$file" "$arguments"
            echo -e "${GREEN}Local IPv4 Kharej 30.0.0.2${NC}"
            echo -e "${BLUE}Local IPv4 Iran 30.0.0.1${NC}"
            ;;
        2)
            file="tun-client_$arch_name"
            read -p "Enter Iran IPv4 ) : " IRAN_IPV4
            arguments="-server-addr $IRAN_IPV4 -server-port 800 -client-private 30.0.0.2 -server-private 30.0.0.1 -subnet 24 -device tun2 -key azumi -mtu 1400 -verbose true -smux true -tcp-nodelay true -heartbeat false -ping-interval 10 -service-name azumilocal"
            setup_service "$file" "$arguments"
            echo -e "${GREEN}Local IPv4 Kharej 30.0.0.2${NC}"
            echo -e "${BLUE}Local IPv4 Iran 30.0.0.1${NC}"
            ;;
        *) echo -e "${RED}Invalid option!${NC}" && exit ;;
    esac

    echo ''
    read -p "Press Enter to continue..."
}

destroy_service() {
    if [ -f "/etc/systemd/system/azumilocal.service" ]; then
        systemctl stop azumilocal.service
        systemctl disable azumilocal.service
        rm /etc/systemd/system/azumilocal.service
        rm -rf /root/localTUN
        sudo systemctl reset-failed
        echo "Uninstallation completed successfully."
    else
        echo "service isn't installed!"
    fi

    echo ''
    read -p "Press Enter to continue..."
}

reset_service() {
    echo -e "\n${YELLOW}Restarting Azumi local service...${NC}\n"
    sleep 1
    # Restart Azumi local service
    echo ''
    if systemctl restart azumilocal.service ; then
        echo -e "${GREEN}Azumi local service restarted successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to restart Azumi local service.${NC}"
    fi

    echo ''
    read -p "Press Enter to continue..."
}

# Function to display menu
display_menu(){
	clear
	display_server_info
	echo "-------------------------------"
	check_status
    echo "-------------------------------"
    echo "Menu:"
    echo -e "${GREEN}1. Configure Forward Tun (Private & Public IPv4)${NC}"
    echo -e "${BLUE}2. Configure Reverse Tun (Private & Public IPv4)${NC}"
    echo -e "${RED}3. Stop & Remove service and files${NC}"
    echo -e "${YELLOW}4. Restart Service${NC}"
    echo "5. Exit"
    echo "-------------------------------"
  }
# Function to read user input
read_option(){
    read -p "Enter your choice: " choice
    case $choice in
        1) Forward_Tun ;;
        2) Reverse_Tun ;;
        3) destroy_service ;;
        4) reset_service ;;
        5) echo "Exiting..." && exit ;;
        *) echo -e "${RED}Invalid option!${NC}" && sleep 1 ;;
    esac
}



# Main loop
while true
 do
	display_menu
	read_option
done