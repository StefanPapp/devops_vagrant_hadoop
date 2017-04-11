#!/bin/sh
ssh-keygen
cat id_rsa.pub >> authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
yum -y install wget ntp git zsh
systemctl start ntpd
systemctl enable ntpd
systemctl disable firewalld
service firewalld stop
setenforce 0
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
umask 0022
echo umask 0022 >> /etc/profile

groupadd hdfs
groupadd hive
groupadd hadoop

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- updating hosts file"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

sudo mv /tmp/install/hosts /etc/hosts
sudo chown root:root /etc/hosts

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- updating hostname"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

hostnamectl --static set-hostname hdp26

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- get ambari repo"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.5.0.3/ambari.repo -O /etc/yum.repos.d/ambari.repo

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- running yum update"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

yum update -y && yum clean all

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- running yum install"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

yum install ambari-server ambari-agent -y && yum clean all

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- updating ambari-agent.ini"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

sed -i "s/^hostname=localhost/hostname=hdp26.um.local/g" /etc/ambari-agent/conf/ambari-agent.ini


echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- running ambari setup"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

ambari-server setup -s

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- starting ambari server and agent"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

ambari-server start
ambari-agent start

sleep 30

echo " "
echo "---------------------------------------------------------------------------------------------------------------"
echo "----- calling ambari REST apis"
echo "---------------------------------------------------------------------------------------------------------------"
echo " "

curl -H "X-Requested-By: ambari" -X POST -d '@/tmp/install/blueprint.json' -u admin:admin http://hdp26.um.local:8080/api/v1/blueprints/generated
curl -H "X-Requested-By: ambari" -X POST -d '@/tmp/install/create-cluster.json' -u admin:admin http://hdp26.um.local:8080/api/v1/clusters/default

PROGRESS=0
until [ $PROGRESS -eq 100 ]; do
    PROGRESS=`curl --silent --show-error -H "X-Requested-By: ambari" -X GET -u admin:admin http://hdp26.um.local:8080/api/v1/clusters/default/requests/1 2>&1 | grep -oP '\"progress_percent\"\s+\:\s+\K[0-9]+'`
    TIMESTAMP=$(date "+%m/%d/%y %H:%M:%S")
    echo -ne "$TIMESTAMP - $PROGRESS percent complete!"\\r
    sleep 60
done



useradd -G hdfs admin
usermod -a -G users admin
usermod -a -G hadoop admin
usermod -a -G hive admin

usermod -a -G users vagrant
usermod -a -G hdfs vagrant
usermod -a -G hadoop vagrant
usermod -a -G hive vagrant

yum clean all