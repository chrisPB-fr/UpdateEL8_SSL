#!/bin/bash
version=9.3p1
openSSH_repo="https://ftp.lip6.fr/pub/OpenBSD/OpenSSH/portable"
askPass_repo="https://mirror.de.leaseweb.net/slackware/slackware-14.2/source/xap/x11-ssh-askpass"
today=`date +%F`
array_valeur=(y n yes no)
rouge='\e[0;31m'
vert='\e[0;32m'
neutre='\e[0;m'
PATH_RPM="/root/rpmbuild/SOURCES"
OPENSSH_SPEC="${PATH_RPM}/openssh-${version}/contrib/redhat/openssh.spec"

function check_version_ssh () {
check_version=`rpm -qa |grep openssh-server |awk -F"-" '{print $3}'|head -1`
if [ ${check_version} == ${version} ]
then
echo ""
echo -e "${vert}#######################################${neutre}"
echo -e "${vert}  OpenSSL est déja à la version 9.3p1${neutre}"
echo -e "${vert}#######################################${neutre}"
exit
fi
echo "Votre version est la ${check_version}"
}

function install_dependance () {
VERSION=`cat /etc/os-release |grep VERSION_ID |awk -F"=" '{print $2}'|cut -c 2`
if [ ${VERSION} == 7 ]
then
        echo "Installation du paquet dnf"
        dnf -y install dnf >> /dev/null
        echo "Installation du paquet imake"
        yum install imake -y >> /dev/null
else
        echo "Installation du paquet imake"
        dnf --enablerepo=powertools install imake -y >> /dev/null

fi
for install_packet in pam-devel rpm-build rpmdevtools zlib-devel openssl-devel krb5-devel gcc wget gtk2-devel libXt-devel libX11-devel perl
do
        echo "Installation du paquet ${install_packet}"
        dnf -y install ${install_packet} >> /dev/null
done
}


function recup_source () {
## Source OpenSSH
mkdir -p  ${PATH_RPM} 

if [ -f ${PATH_RPM}/openssh-${version}.tar.gz ]
then 
	rm -f ${PATH_RPM}/openssh-${version}.tar.gz
	echo "Récupère les sources de openssh-${version}"
	wget c ${openSSH_repo}/openssh-${version}.tar.gz -P ${PATH_RPM}
else
	echo "Récupère les sources de openssh-${version}"
	wget -c ${openSSH_repo}/openssh-${version}.tar.gz -P ${PATH_RPM} 
fi

if [ -f ${PATH_RPM}/openssh-${version}.tar.gz.asc ]
then
	rm -f ${PATH_RPM}/openssh-${version}.tar.gz.asc
	echo "Récupère les clefs de openssh-${version}"
	wget -c ${openSSH_repo}/openssh-${version}.tar.gz.asc -P ${PATH_RPM}
else
	echo "Récupère les clefs de openssh-${version}"
	wget -c ${openSSH_repo}/openssh-${version}.tar.gz.asc -P${PATH_RPM} 
fi

## Source askpass
if [ -f ${PATH_RPM}/x11-ssh-askpass-1.2.4.1.tar.gz ]
then
	rm -f  ${PATH_RPM}/x11-ssh-askpass-1.2.4.1.tar.gz
	echo "Récupère les sources x11-ssh-askpass"
	wget -c ${askPass_repo}/x11-ssh-askpass-1.2.4.1.tar.gz -P ${PATH_RPM} 
else
        echo "Récupère les sources x11-ssh-askpass"
        wget -c ${askPass_repo}/x11-ssh-askpass-1.2.4.1.tar.gz -P ${PATH_RPM}
fi

}

function prepa_spec () {
cd ${PATH_RPM}
tar -zxvf  openssh-${version}.tar.gz 
yes | cp /etc/pam.d/sshd  openssh-${version}/contrib/redhat/sshd.pam
mv  openssh-${version}.tar.gz{,.orig}
tar -czpf openssh-${version}.tar.gz openssh-${version}
tar -zxvf  openssh-9.3p1.tar.gz openssh-${version}/contrib/redhat/openssh.spec

}

function ajust_spec () {
OPENSSH_SPEC="${PATH_RPM}/openssh-${version}/contrib/redhat/openssh.spec"
chown root.root ${OPENSSH_SPEC}

sed -i -e "s/%define no_gnome_askpass 0/%define no_gnome_askpass 1/g" ${OPENSSH_SPEC}
sed -i -e "s/%define no_x11_askpass 0/%define no_x11_askpass 1/g" ${OPENSSH_SPEC}
sed -i -e "s/BuildPreReq/BuildRequires/g" ${OPENSSH_SPEC}
sed -i -e "s/PreReq: initscripts >= 5.00/#PreReq: initscripts >= 5.00/g" ${OPENSSH_SPEC}
sed -i -e "s/BuildRequires: openssl-devel < 1.1/#BuildRequires: openssl-devel < 1.1/g" ${OPENSSH_SPEC}
sed -i -e "/check-files/ s/^#*/#/"  /usr/lib/rpm/macros
}

function create_RPM () {
cd ${PATH_RPM}/openssh-${version}/contrib/redhat/
rpmbuild -ba openssh.spec
cd  /root/rpmbuild/RPMS/x86_64/
ls -al |grep openssh*
}

function install_RPM () {
## sauvegarde conf ssh PAM conf
cd  /root/rpmbuild/RPMS/x86_64/
cp /etc/pam.d/sshd pam-ssh-conf-${today}

## Installation OpenSSL 9.3p1
rpm -Uvh *.rpm

## restauration ssh PAM conf
mv /etc/pam.d/sshd /etc/pam.d/sshd_93p1_${today}
yes | cp pam-ssh-conf-${today} /etc/pam.d/sshd
}

function autorise_root_acces () {

printf "souhaitez vous activer root acces [yes,no]: "
read -r reponse

while ! [[ "${array_valeur[@]}" =~ ${reponse} ]];do 
	autorise_root_acces
done

if [ ${reponse} == yes ] || [ ${reponse} == y ] 
then
	check_acces_root=`cat /etc/ssh/sshd_config |grep "PermitRootLogin prohibit-password" |wc -l`
	if [ ${check_acces_root} == 1 ]
	then
		sed -i 's/prohibit-password/yes/'  /etc/ssh/sshd_config
	fi
	check_actif_acces_root=`cat /etc/ssh/sshd_config |grep "#PermitRootLogin" |wc -l`
	if [ ${check_actif_acces_root} == 1 ]
	then
		sed -i 's/#PermitRootLogin/PermitRootLogin/'  /etc/ssh/sshd_config	
	fi
echo ""
echo -e "${vert}#####################################${neutre}"
echo -e "${vert}   Root Acces est désormais activé   ${neutre}" 
echo -e "${vert}#####################################${neutre}"
fi
}

function activation_pam () {
	check_pam_actif=`cat /etc/ssh/sshd_config |grep "#UsePAM yes" |wc -l`
	if [ ${check_pam_actif} == 1 ]
	then
		sed -i 's/#UsePAM no/UsePAM yes/'  /etc/ssh/sshd_config
	fi 
echo ""
echo -e "${vert}#####################################${neutre}"
echo -e "${vert}   Authentification PAM est activé   ${neutre}"
echo -e "${vert}#####################################${neutre}"

}

function check_host_rsa_key () {
if [ ! -f "/etc/ssh/ssh_host_dsa_key" ]
then
	ssh-keygen -t rsa -f /etc/ssh/ssh_host_dsa_key -q -P ""
fi
chmod -R 600 /etc/ssh/
}

function restart_sshd () {
systemctl restart sshd
systemctl status sshd
}
clear
#### Lancement de l'installation 
echo ""
echo -e "${vert}############################${neutre}"
echo -e "${vert}  Mise à jour de OpenSSL    ${neutre}"
echo -e "${vert}############################${neutre}"
sleep 2

clear
echo ""
echo -e "${vert}######################################${neutre}"
echo -e "${vert}  Etape 1 - Check la version OpenSSL  ${neutre}"
echo -e "${vert}######################################${neutre}"
sleep 2
check_version_ssh

clear
echo ""
echo -e "${vert}##########################################${neutre}"
echo -e "${vert}  Etape 2 - installation des dépendances  ${neutre}"
echo -e "${vert}##########################################${neutre}"
sleep 2
install_dependance

clear
echo -e "${vert}##########################################${neutre}"
echo -e "${vert}   Etape 3 -  Récupération des sources    ${neutre}"
echo -e "${vert}##########################################${neutre}"
sleep 2
recup_source

clear
echo -e "${vert}##########################################${neutre}"
echo -e "${vert}  Etape 4 -  Préparation du fichier spec  ${neutre}"
echo -e "${vert}##########################################${neutre}"
sleep 2
prepa_spec

clear
echo -e "${vert}########################################${neutre}"
echo -e "${vert}  Etape 5 -  Ajustement du fichier spec ${neutre}"
echo -e "${vert}########################################${neutre}"
sleep 2
ajust_spec

clear
echo -e "${vert}#################################################${neutre}"
echo -e "${vert}  Etape 6 -  Création des RPM OpenSSL ${version} ${neutre}"
echo -e "${vert}#################################################${neutre}"
sleep 2
create_RPM

clear
echo -e "${vert}######################################################${neutre}"
echo -e "${vert}  Etape 7 -  installation des  RPM OpenSSL ${version} ${neutre}"
echo -e "${vert}######################################################${neutre}"
sleep 2
install_RPM

clear
echo -e "${vert}######################################${neutre}"
echo -e "${vert}  Etape 8 -  Ouverture root acces SSH ${neutre}"
echo -e "${vert}######################################${neutre}"
sleep 2
autorise_root_acces

clear
echo -e "${vert}#############################################${neutre}"
echo -e "${vert}  Etape 9 - Activation authentification  PAM ${neutre}"
echo -e "${vert}#############################################${neutre}"
sleep 2
#activation_pam
sleep 10

clear
echo -e "${vert}###########################################${neutre}"
echo -e "${vert}  Etape 10 - Correction Bug Vertificat RSA ${neutre}"
echo -e "${vert}###########################################${neutre}"
sleep 2
check_host_rsa_key

#clear
echo -e "${vert}############################################${neutre}"
echo -e "${vert}  Etape Finale - Redémarrage du service SSH ${neutre}"
echo -e "${vert}############################################${neutre}"
sleep 2
restart_sshd

