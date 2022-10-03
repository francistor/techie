#!/bin/bash

grep -q 'ldap-ggc' /etc/apparmor.d/usr.sbin.slapd 

if [ "$?" != "0" ] 
then
	# -i for in place
	sed -i 's/# the databases and logs/# the databases and logs\n  \/var\/lib\/ldap-ggc\/ r,\n  \/var\/lib\/ldap-ggc\/** rwk,/g' /etc/apparmor.d/usr.sbin.slapd
	sed -i 's/# the databases and logs/# the databases and logs\n  \/var\/lib\/ldap-pv\/ r,\n  \/var\/lib\/ldap-pv\/** rwk,/g'    /etc/apparmor.d/usr.sbin.slapd
	sed -i 's/# lock file/# lock file\n  \/var\/lib\/ldap-ggc\/alock kw,/g' /etc/apparmor.d/usr.sbin.slapd
	sed -i 's/# lock file/# lock file\n  \/var\/lib\/ldap-pv\/alock kw,/g'  /etc/apparmor.d/usr.sbin.slapd
	
else
	echo "apparmor already set up"
fi

service apparmor restart

