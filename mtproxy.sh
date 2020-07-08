#!/bin/bash
rm -- "$0"
echo "开始安装mtproxy"
apt update 2>/dev/null
apt install git python3-pip curl xxd bc lsof -y 2>/dev/null
yum update -y 2>/dev/null
yum install git python3-pip curl vim-common bc lsof -y 2>/dev/null
pip3 install cryptography
pid=`ps aux | grep mtprotoproxy.py | grep -v "grep" | awk '{print $2}'`
if [ "$pid" != "" ]; then
  if [ -f "/etc/systemd/system/mtproxy.service" ]; then
    systemctl stop mtproxy
    systemctl disable mtproxy
  else
    kill -9 $pid
  fi
fi
if [ -d "/etc/mtproxy" ]; then
  rm -rf /etc/mtproxy
fi
git clone https://github.com/chummumm/mtprotoproxy.git /etc/mtproxy
while :
do
  echo -n -e "\033[32m请输入mtproxy运行端口:\033[0m"
  read num
  if [ ! -n "$num" ]; then
    echo -e "\033[32m端口已设置为默认（1973）\033[0m"
    num=1973
    break
  else
    judge=`echo "$num*1" | bc `
    if [ $judge -ne 0 2>/dev/null ]; then
      echo "正在判断端口是否被占用......"
      port_test=`lsof -i:$num | grep -i listen | grep -v "PID" | awk '{print $2}'`
      if [ "$port_test" != "" ]; then
        echo -e "\033[31m端口已被占用\033[0m"
      else
        sed -i "s/1973/$num/g" /etc/mtproxy/config.py
	break
      fi
    else
      echo -e "\033[31m输入错误，端口号应为整数\033[0m"
    fi
  fi
done
echo "正在随机生成secret......"
secret=$(head -c 16 /dev/urandom | xxd -ps)
sed -i "s/0000000054655212aa12221200000001/$secret/g" /etc/mtproxy/config.py
sed -i 's/"secure": False,/"secure": True,/g' /etc/mtproxy/config.py
sed -i 's/AD_TAG/#AD_TAG/g' /etc/mtproxy/config.py
echo -n -e "\033[32m请输入需要伪装的域名:\033[0m"
read domain
if [ ! -n "$domain" ]; then
  echo -e "\033[32m使用默认伪装域名（www.cloudflare.com）\033[0m"
  domain=www.cloudflare.com
else
  sed -i "s/www.cloudflare.com/$domain/g" /etc/mtproxy/config.py 
fi
STR="$domain"
HEXVAL=$(xxd -pu <<< "$STR")
hexdomain=${HEXVAL%0a}
ip=$(curl -4 -k ip.sb)
echo "开始注册mtproxy守护进程......"
wget -q --no-check-certificate https://raw.githubusercontent.com/chummumm/one-key-mtp/master/mtproxy.service -O /etc/systemd/system/mtproxy.service
sed -i "s/mtprotoproxy.py/\/etc\/mtproxy\/mtprotoproxy.py/g" /etc/systemd/system/mtproxy.service
systemctl daemon-reload
systemctl enable mtproxy
systemctl start mtproxy
systemctl restart mtproxy
echo "完成."
clear
echo "mtproxy.service已注册"
echo -e "\033[34m请手动放行防火墙端口\033[0m"
echo -e "\033[33m请使用 systemctl status mtproxy 命令查看证书是否获取成功！！！！！！\033[0m"
echo -e "\033[32m代理信息：\033[0m"
echo -e "\033[32mtg://proxy?server=$ip&port=$num&secret=dd$secret\033[0m"
echo -e "\033[32mtg://proxy?server=$ip&port=$num&secret=ee$secret$hexdomain\033[0m"
echo -e "\033[36mtg://proxy?server=$ip&port=$num&secret=dd$secret\033[0m" > /etc/mtproxy/secret
echo -e "\033[36mtg://proxy?server=$ip&port=$num&secret=ee$secret$hexdomain\033[0m" >> /etc/mtproxy/secret
echo -e "\033[36m后续查看配置信息可使用 cat /etc/mtproxy/secret\033[0m"
echo "删除mtproxy及其守护进程请运行： wget --no-check-certificate https://raw.githubusercontent.com/pipixia244/one-key-mtp/master/deletemtproxy.sh && bash deletemtproxy.sh"
