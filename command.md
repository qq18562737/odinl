

# 安装 LXC: 
sudo apt install lxc lxc-templates

#最的理手动下载后复制到机器里的 windodws 上下载的 https://images.linuxcontainers.org/images/ubuntu/focal/amd64/default/20250328_07%3A42/
#https://images.linuxcontainers.org/images/ubuntu/focal/amd64/default/20250328_07%3A42/
# 手动创建容器
sudo lxc-create -n ubuntu-e -t none
sudo mkdir -p /var/lib/lxc/ubuntu-e/rootfs
sudo tar -Jxf rootfs.tar.xz -C /var/lib/lxc/ubuntu-e/rootfs

#需要配置一下
sudo bash -c 'cat > /var/lib/lxc/ubuntu-e/config << EOF
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = x86_64
lxc.rootfs.path = dir:/var/lib/lxc/ubuntu-e/rootfs
lxc.uts.name = ubuntu-e

# 网络配置
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:3e:11:11:11
EOF'

#启动
sudo lxc-start -n ubuntu-e
sudo lxc-attach -n ubuntu-e

# 处理删除
sudo lxc-info -n ubuntu-e
sudo lxc-stop -n ubuntu-e -k
sudo lxc-destroy -n ubuntu-e


#查看网络活动以确认是否正在下载
sudo apt install iftop
sudo iftop
# 更新包列表
apt update
# 直接安装 wget
apt install wget -y
# 直接安装 unzip
apt install unzip -y
apt update && apt install -y curl
apt install nano -y
#支持SOCKETS5的代理
sudo apt install proxychains
sudo nano /etc/proxychains.conf
socks5 109.110.186.46 12324 aaa888 aaa888

socks5 47.254.27.22 3344 aa1111 aa1111

proxychains mix deps.get

export ALL_PROXY="socks5h://aaa888:aaa888@109.110.186.46:12324"
export ALL_PROXY="socks5h://aa1111:aa1111@47.254.27.22:3344"
export ALL_PROXY="socks5://zhao:zhao@154.84.35.102:11080"
export http_proxy="http://wzy861123:wzy861123@146.19.154.215:12324"
export https_proxy="http://wzy861123:wzy861123@146.19.154.215:12324"


export ALL_PROXY="socks5://zhao:zhao@154.84.35.102:11080"
export ALL_PROXY="socks5h://zhao:zhao@154.84.35.102:11080"
export http_proxy="http://aaa888:aaa888@109.110.186.46:12324"
export https_proxy="https://aaa888:aaa888@109.110.186.46:12324"
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
#删除
unset http_proxy
unset https_proxy
unset ALL_PROXY
#查看
echo $http_proxy
echo $https_proxy
echo $ALL_PROXY

#代理测试
proxychains
curl -v https://ipinfo.io
curl -x socks5://aaa888:aaa888@109.110.186.46:12324 http://ipinfo.io
curl -x socks5://zhao:zhao@154.84.35.102:11080 http://ipinfo.io
curl -x socks5://zhao:zhao@154.84.35.102:11080  https://ipinfo.io
curl -x socks5://ldd007:Wxl111@43.201.247.210:65301  http://ipinfo.io

curl -x socks5h://zhao:zhao@154.84.35.102:11080 https://www.google.com
# -k 是关闭了一些东西 临时绕过验证（仅测试用）
curl -k socks5://zhao:zhao@154.84.35.102:11080 https://www.google.com
47.254.27.22/3344/aa1111/aa1111   美国IP
193.108.104.136:12323:wzy861123:wzy861123
45.130.79.221:12324:aaa888:aaa888
# 测试socks5h（远程解析）
curl -v --proxy socks5h://zhao:zhao@154.84.35.102:11080 https://www.google.com
curl -v --proxy socks5h://aa1111:aa1111@47.254.27.22:3344 https://www.google.com
curl -v  socks5h://aa1111:aa1111@47.254.27.22:3344 https://www.google.com
#这样是可以的 socks5h
curl -x socks5h://aaa888:aaa888@109.110.186.46:12324 https://hex.pm
curl -x socks5://aaa888:aaa888@109.110.186.46:12324 https://www.google.com
curl -x socks5h://aaa888:aaa888@109.110.186.46:12324 https://accounts.google.com
curl -x socks5h://aaa888:aaa888@45.130.79.221:12324 https://www.google.com
# 测试socks5（本地解析）
curl -v --proxy socks5://zhao:zhao@154.84.35.102:11080 https://www.google.com
https://hex.pm
#============================
HTTP_PROXY=http://192.168.2.153:1080 HTTPS_PROXY=http://192.168.2.153:1080 mix deps.get
HTTP_PROXY=http://zhao:zhao@154.84.35.102:11808 HTTPS_PROXY=http://zhao:zhao@154.84.35.102:11808 curl -v https://ipinfo.io
HTTP_PROXY=http://zhao:zhao@154.84.35.102:11808 HTTPS_PROXY=http://zhao:zhao@154.84.35.102:11808 curl -v https://www.google.com
HTTP_PROXY=http://aaa888:aaa888@45.130.79.221:12324 HTTPS_PROXY=http:aaa888:aaa888@45.130.79.221:12324 mix deps.get
HTTP_PROXY=http://aaa888:aaa888@109.110.186.46:12324 HTTPS_PROXY=http://aaa888:aaa888@109.110.186.46:12324 mix deps.get
# 安装工具
apt update
apt update && apt install -y curl

timestamp=$(date +%s)000
username="RCKLZ0XLD3yD8IGm"
password="593chgaqlksdyh91"
proxy_host="geo.iproyal.com"
proxy_port="12321"

curl -x "http://${username}:${password}@${proxy_host}:${proxy_port}" \
     -v "https://www.google.com"

username="wzy861123"
password="wzy861123"
proxy_host="45.133.109.90"
proxy_port="12323"

curl -x "http://${username}:${password}@${proxy_host}:${proxy_port}" \
     -v "https://www.google.com"

curl -x socks5://aa1111:aa1111@47.254.27.22:3344  http://ipinfo.io
curl -x socks5://RCKLZ0XLD3yD8IGm:593chgaqlksdyh91@geo.iproyal.com:12321  http://ipinfo.io

curl -x socks5://aa1111:aa1111@47.254.27.22:3344  https://www.google.com
curl -x socks5://RCKLZ0XLD3yD8IGm:593chgaqlksdyh91@geo.iproyal.com:12321  https://www.google.com

apt install -y wget unzip
apt install -y unzip
apt install -y curl
# 创建目录
mkdir -p ~/chrome-for-testing
cd ~/chrome-for-testing
#===============================================115============================================
# 下载 Chrome for Testing (115.0.5763.0)
wget https://storage.googleapis.com/chrome-for-testing-public/115.0.5763.0/linux64/chrome-linux64.zip
unzip chrome-linux64.zip

# 下载匹配的 ChromeDriver
wget https://storage.googleapis.com/chrome-for-testing-public/115.0.5763.0/linux64/chromedriver-linux64.zip
unzip chromedriver-linux64.zip

# 将 Chrome 二进制文件链接到全局路径
sudo ln -s ~/chrome-for-testing/chrome-linux64/chrome /usr/local/bin/google-chrome
sudo chmod +x /usr/local/bin/google-chrome

# 将 ChromeDriver 链接到全局路径
sudo ln -s ~/chrome-for-testing/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
sudo chmod +x /usr/local/bin/chromedriver

# 移除旧链接和安装
sudo rm -f /usr/local/bin/google-chrome
sudo rm -f /usr/local/bin/chromedriver
rm -rf ~/chrome-for-testing
#=================================================135================================================
# https://googlechromelabs.github.io/chrome-for-testing/#stable
wget https://storage.googleapis.com/chrome-for-testing-public/135.0.7049.42/linux64/chrome-linux64.zip

# 解压到指定目录
unzip chrome-linux64.zip -d ~/chrome-for-testing

# 创建符号链接
sudo ln -sf ~/chrome-for-testing/chrome-linux64/chrome /usr/local/bin/google-chrome
sudo chmod +x /usr/local/bin/google-chrome

# 验证安装
google-chrome --version
# 应输出：Google Chrome 135.0.7049.42
#------------------------------------------------------------------------------------------------------
wget -c "https://storage.googleapis.com/chrome-for-testing-public/135.0.7049.42/linux64/chromedriver-linux64.zip"

# 解压到指定目录
unzip chromedriver-linux64.zip -d ~/chrome-for-testing

# 设置可执行权限
chmod +x ~/chrome-for-testing/chromedriver-linux64/chromedriver

# 创建系统级软链接
sudo ln -sf ~/chrome-for-testing/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
sudo chmod +x /usr/local/bin/chromedriver

# 验证安装
chromedriver --version
# 应输出：ChromeDriver 135.0.7049.42 (...)
#---------------------------------------------------------------------------------------------------------
sudo apt update
sudo apt install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libatspi2.0-0 \
    libwayland-client0

# 检查库文件是否存在
ls /usr/lib/x86_64-linux-gnu/libnss3.so

sudo apt update
sudo apt install -y libpango-1.0-0 libpangocairo-1.0-0

sudo apt install -y \
    libgtk-3-0 \
    libx11-xcb1 \
    libxss1 \
    libxtst6 \
    libgdk-pixbuf2.0-0 \
    libappindicator3-1

ls -l /usr/lib/x86_64-linux-gnu/libpango-1.0.so.0
# 应该显示类似：/usr/lib/x86_64-linux-gnu/libpango-1.0.so.0 -> libpango-1.0.so.0.4000.14



# 验证 Chrome 版本
google-chrome --version
# 验证 ChromeDriver 版本
chromedriver --version
 

which google-chrome
which chromedriver


python3.9 -m pip list | grep -E "selenium-wire|undetected-chromedriver|selenium"

Google Chrome for Testing 115.0.5763.0
ChromeDriver 115.0.5763.0 (ae02e6bd7115b8d7be1d1ed69a4177c3802a5070-refs/branch-heads/5763@{#1})
/usr/local/bin/google-chrome
/usr/local/bin/chromedriver

#==========================================================================================
# 1. 安装编译依赖
sudo apt update
sudo apt install -y build-essential zlib1g-dev libncurses5-dev \
libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev \
libsqlite3-dev wget libbz2-dev

# 2. 下载源码（替换为最新3.9.x版本）
wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tar.xz
tar -xf Python-3.9.18.tar.xz
cd Python-3.9.18

# 3. 编译安装（优化选项）
./configure --enable-optimizations
make -j $(nproc)
sudo make altinstall  # 使用altinstall避免替换系统Python

# 4. 验证
python3.9 --version
#==========================================================================================
#这个方法可以装python3.9.22
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.9

curl https://bootstrap.pypa.io/get-pip.py | python3.9
#--------------------------------------------------------
# 4. 安装 Python 3.9 有可能会装不上没有这个库
sudo apt install -y python3.9 python3.9-dev python3.9-venv
#这个需要安装
sudo apt install python3.9-venv python3.9-distutils

wget https://bootstrap.pypa.io/get-pip.py
python3.9 get-pip.py --user
rm get-pip.py

    #将 pip 加入 PATH 
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc

    #验证 pip 安装
python3.9 -m pip --version

python3.9 --version

#默認 ver: 3.5.5
python3.9 -m pip install undetected-chromedriver
#ver: 4.31.0
python3.9 -m pip install  selenium
#ver: 5.1.0
python3.9 -m pip install  selenium-wire
python3.9 -m pip install   anticaptchaofficial
python3.9 -m pip install xvfbwrapper
python3.9 -m pip install bs4
sudo apt update
sudo apt install -y xvfb xserver-xephyr
#这是一个集合命令
proxychains pip3 install  selenium undetected-chromedriver selenium-wire bs4 anticaptchaofficial xvfbwrapper

#命令查看
 python3.9 -m pip list | grep -E "selenium-wire|undetected-chromedriver|selenium"
selenium                4.31.0
selenium-wire           5.1.0
undetected-chromedriver 3.5.5 #https://github.com/ultrafunkamsterdam/undetected-chromedriver?tab=readme-ov-file

# 以下模塊可以駔證通過
# 验证包是否可导入
python3.9 -c "import seleniumwire.undetected_chromedriver.v2 as uc; print('导入成功')"

# 查看精确版本
python3.9 -c "
import undetected_chromedriver as uc;
import seleniumwire;
print(f'undetected-chromedriver: {uc.__version__}');
print(f'selenium-wire: {seleniumwire.__version__}');
"
#=================================處理問題========================================================
# 卸载所有相关包（包括系统级和用户级）
sudo python3.9 -m pip uninstall undetected-chromedriver selenium-wire selenium -y
python3.9 -m pip uninstall undetected-chromedriver selenium-wire selenium -y

# 清除所有残留文件
sudo rm -rf /usr/local/lib/python3.9/dist-packages/{undetected_chromedriver,seleniumwire}*
rm -rf ~/.local/lib/python3.9/site-packages/{undetected_chromedriver,seleniumwire}*

# 创建纯净虚拟环境
python3.9 -m venv ~/selenium_env
source ~/selenium_env/bin/activate

# ============================================================================

sudo apt install xvfb
xvfb-run python3.9 proxy_test_uc.py

#import blinker._saferef
# 先卸载有问题的版本
python3.9 -m pip uninstall blinker -y
# 安装正确版本的 blinker
python3.9 -m pip install --force-reinstall blinker==1.4
python3.9 -m pip install --user --force-reinstall blinker==1.4
#手动安装字体：
apt update && apt install -y fonts-wqy-microhei


#检查证书问题根源：這個沒有什麼用
openssl s_client -connect geo.iproyal.com:12321 -showcerts

#https://anti-captcha.com/zh
# 卸载后重新安装
python3.9 -m pip uninstall anticaptchaofficial
python3.9 -m pip install anticaptchaofficial
python3.9 -c "from anticaptchaofficial.imagecaptcha import *; print('导入成功')"


# 创建注册管理器
register_uuid = Actor.AutoRegister.create()

# 添加注册站点 (使用实际注册页面URL)
Actor.AutoRegister.add_sites(register_uuid, [
  "targetsite.com/register",
  "anotherforum.com/signup"
])

# 添加账户到注册队列
added = Actor.AutoRegister.add_to_queue(register_uuid, 1)
IO.puts("Added #{added} accounts to registration queue")

# 检查注册状态
Actor.AutoRegister.debug(register_uuid)



# 获取详细状态
status = Actor.AutoRegister.get_status(register_uuid)
IO.inspect(status)

# 获取已完成注册的详细信息
completed = Actor.AutoRegister.get_completed_details(register_uuid)
IO.inspect(completed)
# 停止
Actor.AutoRegister.delete_all

#=====================================================================
accs = MnesiaKV.get(Account) |> Enum.filter(&(&1[:blocked])  ) |> Enum.take(1)
accs = MnesiaKV.get(Account) |> Enum.filter(&(&1[:status])  ) |> Enum.take(1)
accs = MnesiaKV.get(Account) |> Enum.count
actor = MnesiaKV.get(Actor)

#=====================================================================
#服务器添加秘钥
chmod 700 ~/.ssh 
cat ~/.ssh/authorized_keys
#添加允许的机器
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDbDjKdWcxlAUAZnev/qNHqsqE2kwAgruHrWlxGF9uaijIq5o9ooCZ1KSRzjIopA2aPBC+WzRV1zvCZbD/8QEpaX+1iWIojXKqNStXALZPQfCy23Ym0k8nJD/1ShPv1Se2nARj8IVpxWA8Hr+5VcSbWtx0CFUcfMqSGB3IkrS8bvOIqgfBiOcc8WHsP1apLJ+oDjtSOFXbZTr4d8ABFtoDl1jld+rdE8hEsiu11ZJhzZJmxnTo4ZLmk6GP1gFW3dQ45rHSaAqxYtVu/esrc1iaW6tCwCkxyT/bUskHFGzbwvdte/2aHs8RfIuafy3lHYwC6NL7YwPTA+jUbkS68/lBnXc0V1ViqMRdfAegKVqincHP2QjTcxMTzXXvVubOa4dWLyAhJrVzFNKu5rvyG3KENb6Yl4oEVK7Vbi8wTWvr8jdKWhh2zMWeYcKGPj9s3HpB4nqHXsPteqim9dCIs8889OZ1Z2LYs+cDkyn7KavR10l7JXj0aZc9Ph7TrPCo0q/4kc2eeKJl0TtOtBZ5yf5zwGZq7vSOxn1NDVgUpIBlbIsCfkRHM4rUBHgzggba9SkdZ+7+H1Bem9vmtLAPu3RNseK3iZbWdUrAZe3e4sNT+xrd0RhmMBQTrmD/YnCaQF/+hQR12oHHXM0ShQirbHubIKqhxBsyA4CaDCTCjNvtBjQ== root@zhao-VMware-Virtual-Platform" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5u6WrjsPnBRL15HLmtS7mScfVEkxPtd4zHXW9Puqjk43xEyAGI/5FltXjMY1K12IvmQ6h/QcFuC67uhZC7gg5LpEZaxmI+myDmwW6OOcQCBjP6HBXC9w8nE347wO96OVttZTNhL+WJXmS2slxHmRUXyGUdUViU7hhLbPD2vy0NC6oFgQjNScdGxKC+yINV/Xgj4WunIH3WrXF8u70l+eRZVs7L9gbvyegZrovQv33M3yeDpx4DG0YpnmL/fUJrexRZTde2bC7TEOnB4SbxGXCwEEEtyN6yJlfFQ4aBBZPMF7hH1ZazmyH93eWSQGcH4BGrinav3zZu+g4XFNa73klLe+lnI5Nw0s+On4jmy9Vtuuf1CVvh9Q1cpaf2FIEklxc6e5pKr0fWF4sTtB2Waa8t5+jqugwoBn2YV3msK2nLw5rWhErCLLDF+EgdsexXxkmwFZKl2QVAMCirV7iHdD7E1ZQOfDi3lIKnpyM8TpXNrR9QMbYP5iWuq1MzIJFIr4oi/wm3CZptFnMPp8RBuEeZoVnowaxph/BJ8jDj4HnA4rDDm/D3R7xy/994pstcddw0BY6Znz1Na55yfMA2RLV5NHSuAgjhVkJt8B4hqIixVDxFAII6KdPBw4fT+3a3tBEXYCC+fQapfjxUCPABGTeBhWiH+dREYi4R8uwhG7JHw== administrator@DESKTOP-M2LAKUL" >> ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5u6WrjsPnBRL15HLmtS7mScfVEkxPtd4zHXW9Puqjk43xEyAGI/5FltXjMY1K12IvmQ6h/QcFuC67uhZC7gg5LpEZaxmI+myDmwW6OOcQCBjP6HBXC9w8nE347wO96OVttZTNhL+WJXmS2slxHmRUXyGUdUViU7hhLbPD2vy0NC6oFgQjNScdGxKC+yINV/Xgj4WunIH3WrXF8u70l+eRZVs7L9gbvyegZrovQv33M3yeDpx4DG0YpnmL/fUJrexRZTde2bC7TEOnB4SbxGXCwEEEtyN6yJlfFQ4aBBZPMF7hH1ZazmyH93eWSQGcH4BGrinav3zZu+g4XFNa73klLe+lnI5Nw0s+On4jmy9Vtuuf1CVvh9Q1cpaf2FIEklxc6e5pKr0fWF4sTtB2Waa8t5+jqugwoBn2YV3msK2nLw5rWhErCLLDF+EgdsexXxkmwFZKl2QVAMCirV7iHdD7E1ZQOfDi3lIKnpyM8TpXNrR9QMbYP5iWuq1MzIJFIr4oi/wm3CZptFnMPp8RBuEeZoVnowaxph/BJ8jDj4HnA4rDDm/D3R7xy/994pstcddw0BY6Znz1Na55yfMA2RLV5NHSuAgjhVkJt8B4hqIixVDxFAII6KdPBw4fT+3a3tBEXYCC+fQapfjxUCPABGTeBhWiH+dREYi4R8uwhG7JHw== administrator@DESKTOP-M2LAKUL
chmod 700 ~/.ssh 
sudo nano ~/.ssh/authorized_keys

sudo nano /etc/ssh/sshd_config
#修改端口 22
#打开秘钥设置
PubkeyAuthentication yes
#重启SSH服务
sudo systemctl restart sshd

#关闭密码
PasswordAuthentication no
ChallengeResponseAuthentication no
#软件连接教程
#https://www.jb51.net/program/297215ccw.htm
#远程连接方法
ssh -p 29876 -i ~/.ssh/id_rsa root@8.209.201.80

ssh -v -p 29876 -i "C:\Users\Administrator\.ssh\id_rsa" root@8.209.201.80

tmux new -s "nc" -d
tmux attach-session -t nc

scp -P 29876 /root/script_main.py root@8.209.201.80:/root/