#!/bin/bash

# Base path for domains
BASE_PATH="/var/www"
APACHE_CONF="/etc/apache2/apache2.conf"
HOSTS_FILE="/etc/hosts"

#!/bin/bash

# Define repository URLs and target directories
main_repo="https://github.com/wlp-builders/wlp"
main_repo_dir=`realpath "wlp-core"`
core_plugins_repo="https://github.com/wlp-builders/whitelabelpress-wlp"
core_plugins_dir=`realpath "whitelabelpress-wlp"`

# Clone the main WLP repository if it doesn't already exist
if [ ! -d "$main_repo_dir" ]; then
    echo "Cloning main repository..."
    git clone "$main_repo" "$main_repo_dir"
else
    echo "Main repository already exists, skipping clone."
fi

# Clone the core plugins repository if it doesn't already exist
if [ ! -d "$core_plugins_dir" ]; then
    echo "Cloning core plugins repository..."
    git clone "$core_plugins_repo" "$core_plugins_dir"
else
    echo "Core plugins repository already exists, skipping clone."
fi




WLP_SOURCE=$main_repo_dir
CORE_PACK=$core_plugins_dir


# Count existing folders and determine the next domain number
DOMAIN_NUMBER=$(($(ls -l $BASE_PATH | grep ^d | wc -l) + 1))
DOMAIN_NAME="$1"
FOLDER_PATH="$BASE_PATH/$DOMAIN_NAME"

# Update /etc/hosts
if ! grep -q "$DOMAIN_NAME" $HOSTS_FILE; then
    echo "127.0.0.1   $DOMAIN_NAME" | sudo tee -a $HOSTS_FILE > /dev/null
    echo "Added $DOMAIN_NAME to $HOSTS_FILE"
else
    echo "$DOMAIN_NAME already exists in $HOSTS_FILE"
fi

# Create the directory structure
if [ ! -d "$FOLDER_PATH" ]; then
    sudo mkdir -p "$FOLDER_PATH"
    echo "Created directory: $FOLDER_PATH"
else
    echo "Directory $FOLDER_PATH already exists"
fi

# Copy WordPress files to the new domain folder
if [ -d "$WLP_SOURCE" ]; then
    sudo cp -r $WLP_SOURCE/* $FOLDER_PATH   
    sudo mkdir $FOLDER_PATH/wlp-core-plugins/
    sudo mkdir $FOLDER_PATH/wlp-core-plugins/available  
    sudo cp -r $CORE_PACK $FOLDER_PATH/wlp-core-plugins/enabled
    sudo chown -R www-data:www-data $FOLDER_PATH
    sudo chmod 770 $FOLDER_PATH -R
    echo "Copied WLP files to $FOLDER_PATH and set permissions"
else
    echo "WLP source files not found at $WLP_SOURCE"
    exit 1
fi

# Append virtual host configuration to apache2.conf
sudo tee -a $APACHE_CONF > /dev/null <<EOF 
<VirtualHost *:80>
    DocumentRoot $FOLDER_PATH
    ServerName $DOMAIN_NAME

    <Directory $FOLDER_PATH>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
echo "Added virtual host for $DOMAIN_NAME to $APACHE_CONF"

# Reload Apache
sudo systemctl reload apache2
echo "Reloaded Apache to apply new configuration"

# Run WordPress installation
INSTALL_SCRIPT="$FOLDER_PATH/wlp-install/autoinstall-as-root.sh"
# Run the installation script and capture output
URL_WITH_PARAMS=$(sudo bash $INSTALL_SCRIPT $FOLDER_PATH)
echo "URL: $URL_WITH_PARAMS";

# Executes with query parameters to create wlp-config file
curl "$URL_WITH_PARAMS"


