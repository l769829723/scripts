#! /usr/bin/env sh

# $1: Database path
# $2: Package name
# $3: Package url

function logging(){
	local_date=$(date +"%H:%M:%S")
	logger -t $0 $1
	echo "[ $USER $local_date ]: $1" | tee -a ${log_path}
}

# 初始化文件下载方法
function download(){
	logging "Downloading the file from $url ."
	rm -f $data_dir/$file_name
	wget --no-check-certificate -P $data_dir $url &>>${log_path}
	if [[ ! -f $data_dir/$file_name ]];then
		logging "Download was failed from $url ."
		exit 400
	fi
}

root_dir=/tmp/mongodb
data_dir=${root_dir}/data
tmp_dir=${root_dir}/tmp
log_path=/var/log/mongodb_install.log
databases_dir=/opt/mongodb

file_name=mongodb263.tgz
file_url=http://files.cloudrabbit.cn/install/mongodb/

logging "Automic installation MongoDB online."
logging "Start to prepare the configuration data..."

if [[ -n $1 ]];then
  databases_dir=$1
fi

if [[ -n $2 ]];then
  file_name=$2
fi

if [[ -n $3 ]];then
  file_url=$3
fi

# Generator the configuration
mkdir -p ${root_dir}
mkdir -p ${data_dir}
mkdir -p ${tmp_dir}
mkdir -p ${databases_dir}
chown -R mongod:mongod ${databases_dir}
touch ${log_path}

logging "Completed, next downloading file ..."
url=${file_url}${file_name}
download;
if [[ ! $? -eq 0 ]];then
  logging "Download failed, pls checkout %{log_path} ."
  exit
fi
logging "Completed, next unpacking the file ..."
tar xf ${data_dir}/${file_name} -C ${tmp_dir} &>>${log_path}
if [[ ! $? -eq 0 ]];then
  "Unpack failed, pls checkout ${log_path} ."
  exit
fi
logging "Completed, next setting up repository ..."
cat >/etc/yum.repos.d/mongodb.repo<<EOF
[mongodb]
name=mongodb ver 2.6.3
baseurl=file://${tmp_dir}
gpgcheck=0
enabled=1
EOF
logging "Completed, next start the installation MongoDB ..."
yum install -y mongodb-org-2.6.3 mongodb-org-server-2.6.3 \
mongodb-org-shell-2.6.3 mongodb-org-mongos-2.6.3 \
mongodb-org-tools-2.6.3 --enablerepo mongodb &>>${log_path}

if [[ ! $? -eq 0 ]];then
  logging "Installation failed, pls checkout ${log_path} ."
  exit
fi
logging "Completed, next reconfigure the MongoDB ."
sed -i "s:$(grep ^dbpath /etc/mongod.conf ):dbpath=${databases_dir}:g" \
/etc/mongod.conf &>>${log_path}
sed -i "s-$(grep ^bind_ip /etc/mongod.conf ):bind_ip=0.0.0.0:g" \
/etc/mongod.conf &>>${log_path}
if [[ ! $? -eq 0 ]];then
  logging "Reconfigure failed, pls checkout ${log_path} ."
fi
logging "Completed, next startup MongoDB service ..."
if [[ -n $(which systemd) ]];then
  systemctl start mongod
  if [[ $? -eq 0 ]];then
    logging "Completed, startup by systemd ."
  else
    systemctl status mongod &>>${log_path}
    logging "Service startup failed, pls checkout ${log_path} ."
    exit
  fi
fi

if [[ -n $(which service) ]];then
  service mongod start
  if [[ $? -eq 0 ]];then
    logging "Completed, startup by sysv ."
  else
    service mongod status &>>${log_path}
    logging "Service startup failed, pls checkout ${log_path} ."
    exit
  fi
fi
logging "####################################"
for e in $(hostname -I);do
  logging " web: http://$e:27017"
done
logging "####################################"
