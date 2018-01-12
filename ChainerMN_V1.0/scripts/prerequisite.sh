yum -y install telnet
rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm
yum -y install jq
yum install -y gcc libffi-devel python-devel openssl-devel
curl -L https://aka.ms/InstallAzureCli | bash 
