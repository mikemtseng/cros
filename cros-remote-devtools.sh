#!/bin/bash
#
# Remote devtools debugging - allows remote connectivity to Chromebook for debugging kiosk session / etc.
#
# Originally from https://github.com/jay0lee/cros-scripts and https://rn-s.net/chrome-dev
#
# Run this script on a Chromebook:
# 1. Put Chromebook in developer mode - https://www.chromium.org/chromium-os/poking-around-your-chrome-os-device
# 2. Log into device. Press CTRL+ALT+T to open crosh shell.
# 3. Type "shell" to enter Bash shell.
# 4. Type:
#      bash <(curl -s -S -L https://git.io/fjyWZ)
#

# Make SSD read/write if it's not
sudo touch /root-is-readwrite &> /dev/null
if [ ! -f /root-is-readwrite ]
then
  read -p "Modifying OS. USB Recovery will be needed to get out of developer mode. Are you sure you want to do this? (y/N): " is_user_sure
  is_user_sure=${is_user_sure:0:1}
  is_user_sure=${is_user_sure,,}
  if [ ! ${is_user_sure} = "y" ]
  then
    echo "Come back when you're sure..."
    exit
  fi

  sudo /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --partitions "2 4"
  sudo mount -o remount,rw /
  if [ $? -ne 0 ]; then
    echo
    echo
    echo
    echo "Reboot needed to enable OS writing. Please re-run script after a restart."
    echo
    echo "Rebooting in 15 seconds..."
    sleep 15
    sudo reboot
  fi
else
  sudo rm -rf /root-is-readwrite
  echo "Root filesystem is already read/write"
fi

# Setup Remote debugging
sudo bash -c 'grep -q -F "9222" /etc/chrome_dev.conf || echo "--remote-debugging-port=9222" >> /etc/chrome_dev.conf'
sudo /usr/libexec/debugd/helpers/dev_features_ssh

cat >/tmp/remote-devtools.conf <<EOL
description  "start ssh for remote connection to Chrome devtools running on localhost"
start on started openssh-server
stop on stopping openssh-server
respawn
pre-start script
  iptables -A INPUT -p tcp --dport 9223 -j ACCEPT -w
  ip6tables -A INPUT -p tcp --dport 9223 -j ACCEPT -w
end script
post-stop script
  iptables -D INPUT -p tcp --dport 9223 -j ACCEPT -w
  ip6tables -D INPUT -p tcp --dport 9223 -j ACCEPT -w
end script
script
  exec ssh -oStrictHostKeyChecking=no -L 0.0.0.0:9223:localhost:9222 localhost -N
end script
EOL

sudo mv /tmp/remote-devtools.conf /etc/init/
sudo chmod 644 /etc/init/remote-devtools.conf
sudo chown root.root /etc/init/remote-devtools.conf

echo
echo "Enabled remote dev tools. Reboot and try accessing to see remote dev-tools:"
ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | while read line ; do
  echo "  http://$line:9223"
done

