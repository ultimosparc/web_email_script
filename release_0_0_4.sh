#!/bin/bash
##--------Variables--------##
DOMAIN=
EMAIL_USER=
NGINX_LOC="/etc/nginx/sites-available"
NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION="customized_default"
PASSWORD=
SUCCESS="Domain name is ok"
FAILURE="Error: domain name format is not correct"
ed=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
programs="nginx certbot python3-certbot-nginx boxes curl iptables"
##--------Functions--------##
domain_validation(){
	case "$1" in
		*.*) 		
			echo $SUCCESS
			;;  
		*  )
			echo $FAILURE | boxes -d peek
			exit ;;
	esac  
}

web_service_setup(){
	DOMAIN="$1"
	grep -v '#' $NGINX_LOC/default  > $NGINX_LOC/$NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION
	if [ $? -eq 1 ]
	then 
		echo "Error: Not all # were removed" | boxes -d peek
		exit 
	fi
	#filter default server
	sed -i -e 's/default_server//g' $NGINX_LOC/$NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION
	grep "default_server" $NGINX_LOC/$NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION
	if [ $? -eq 0 ]
	then 
		echo "Error: Default server was not disabled" | boxes -d peek
		exit
	fi
	#set DNS name
	sed -i -e "s/server_name _/server_name $DOMAIN www.$DOMAIN mail.$DOMAIN www.mail.$DOMAIN/g" $NGINX_LOC/$NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION
	echo $(cat $NGINX_LOC/$NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION) 
	
}

enviroment_preparation(){
	systemctl stop apache2
	apt remove -y ca-certificates
	apt install -y ca-certificates
	apt update -y  
	apt upgrade -y
	apt install -y $programs 
}

input_box(){
	#input selection
	if [[ "$1" == "domain" ]]
	then
		DOMAIN=$(whiptail --inputbox "Please type the domain name without www, http(s) or any subdomain in:" 8 39 Blue --title "Domain Name" 3>&1 1>&2 2>&3)
		# A trick to swap stdout and stderr.
		# Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			echo "User selected Ok and entered >> $DOMAIN <<"
		else
			echo "User selected Cancel"
			echo "Installation aborted"
			exit
		fi
	
	else
		EMAIL_USER=$(whiptail --inputbox "Please type the first email user name in:" 8 39 Blue --title "Domain Name" 3>&1 1>&2 2>&3)	
	
	fi
}
	
intial_user_account_setup(){
	egrep "^$1" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "$1 exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $2)
		useradd -G mail -m -p "$pass" "$1"
		[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
		id $1 &> /dev/null
		if [ $? -eq 0 ]; then
			echo "Created the email account of the intial user >> $1 <<"
		else
			echo "Error: No intial user was created"
			exit 
		fi 
	fi
}
email_service_setup(){
	
	#  >> This code within this function belongs to the GitHub project https://github.com/LukeSmithxyz/emailwiz << 
	
	echo "Installing programs..."
	apt install -y postfix dovecot-imapd dovecot-sieve opendkim spamassassin spamc
	# Check if OpenDKIM is installed and install it if not.
	which opendkim-genkey >/dev/null 2>&1 || apt install -y opendkim-tools
	domain="$DOMAIN"
	subdom=${MAIL_SUBDOM:-mail}
	maildomain="$subdom.$domain"
	certdir="/etc/letsencrypt/live/$maildomain"

	[ ! -d "$certdir" ] && certdir="$(dirname "$(certbot certificates 2>/dev/null | grep "$maildomain\|*.$domain" -A 2 | awk '/Certificate Path/ {print $3}' | head -n1)")"

	[ ! -d "$certdir" ] && echo "Note! You must first have a Let's Encrypt Certbot HTTPS/SSL Certificate for $maildomain.

	Use Let's Encrypt's Certbot to get that and then rerun this script.

	You may need to set up a dummy $maildomain site in nginx or Apache for that to work." && exit

	# NOTE ON POSTCONF COMMANDS

	# The `postconf` command literally just adds the line in question to
	# /etc/postfix/main.cf so if you need to debug something, go there. It replaces
	# any other line that sets the same setting, otherwise it is appended to the
	# end of the file.
	echo "Configuring Postfix's main.cf..."
	# Change the cert/key files to the default locations of the Let's Encrypt cert/key
	postconf -e "smtpd_tls_key_file=$certdir/privkey.pem"
	postconf -e "smtpd_tls_cert_file=$certdir/fullchain.pem"
	postconf -e "smtpd_tls_security_level = may"
	postconf -e "smtpd_tls_auth_only = yes"
	postconf -e "smtp_tls_security_level = may"
	postconf -e "smtp_tls_loglevel = 1"
	postconf -e "smtp_tls_CAfile=$certdir/cert.pem"
	postconf -e "smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
	postconf -e "smtp_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
	postconf -e "smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
	postconf -e "smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
	postconf -e "tls_preempt_cipherlist = yes"
	postconf -e "smtpd_tls_exclude_ciphers = aNULL, LOW, EXP, MEDIUM, ADH, AECDH, MD5, DSS, ECDSA, CAMELLIA128, 3DES, CAMELLIA256, RSA+AES, eNULL"
	postconf -e "smtpd_sasl_auth_enable = yes"
	postconf -e "smtpd_sasl_type = dovecot"
	postconf -e "smtpd_sasl_path = private/auth"
	
	# Sender and recipient restrictions
	postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"

	postconf -e "home_mailbox = Mail/Inbox/"

	# master.cf
	echo "Configuring Postfix's master.cf..."
	sed -i "/^\s*-o/d;/^\s*submission/d;/^\s*smtp/d" /etc/postfix/master.cf

	echo "smtp unix - - n - - smtp
	smtp inet n - y - - smtpd
	  -o content_filter=spamassassin
	submission inet n       -       y       -       -       smtpd
	  -o syslog_name=postfix/submission
	  -o smtpd_tls_security_level=encrypt
	  -o smtpd_sasl_auth_enable=yes
	  -o smtpd_tls_auth_only=yes
	smtps     inet  n       -       y       -       -       smtpd
	  -o syslog_name=postfix/smtps
	  -o smtpd_tls_wrappermode=yes
	  -o smtpd_sasl_auth_enable=yes
	spamassassin unix -     n       n       -       -       pipe
	  user=debian-spamd argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f \${sender} \${recipient}" >> /etc/postfix/master.cf

	# By default, dovecot has a bunch of configs in /etc/dovecot/conf.d/ These
	# files have nice documentation if you want to read it, but it's a huge pain to
	# go through them to organize.  Instead, we simply overwrite
	# /etc/dovecot/dovecot.conf because it's easier to manage. You can get a backup
	# of the original in /usr/share/dovecot if you want.

	echo "Creating Dovecot config..."
	echo "# Dovecot config
	# Note that in the dovecot conf, you can use:
	# %u for username
	# %n for the name in name@domain.tld
	# %d for the domain
	# %h the user's home directory

	# If you're not a brainlet, SSL must be set to required.
	ssl = required
	ssl_cert = <$certdir/fullchain.pem
	ssl_key = <$certdir/privkey.pem
	ssl_min_protocol = TLSv1.2
	ssl_cipher_list = EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA256:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EDH+aRSA+AESGCM:EDH+aRSA+SHA256:EDH+aRSA:EECDH:!aNULL:!eNULL:!MEDIUM:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4:!SEED
	ssl_prefer_server_ciphers = yes
	ssl_dh = </usr/share/dovecot/dh.pem
	# Plaintext login. This is safe and easy thanks to SSL.
	auth_mechanisms = plain login
	auth_username_format = %n

	protocols = \$protocols imap

	# Search for valid users in /etc/passwd
	userdb {
		driver = passwd
	}
	#Fallback: Use plain old PAM to find user passwords
	passdb {
		driver = pam
	}

	# Our mail for each user will be in ~/Mail, and the inbox will be ~/Mail/Inbox
	# The LAYOUT option is also important because otherwise, the boxes will be \`.Sent\` instead of \`Sent\`.
	mail_location = maildir:~/Mail:INBOX=~/Mail/Inbox:LAYOUT=fs
	namespace inbox {
		inbox = yes
		mailbox Drafts {
		special_use = \\Drafts
		auto = subscribe
	}
		mailbox Junk {
		special_use = \\Junk
		auto = subscribe
		autoexpunge = 30d
	}
		mailbox Sent {
		special_use = \\Sent
		auto = subscribe
	}
		mailbox Trash {
		special_use = \\Trash
	}
		mailbox Archive {
		special_use = \\Archive
	}
	}

	# Here we let Postfix use Dovecot's authetication system.
	
	service auth {
	  unix_listener /var/spool/postfix/private/auth {
		mode = 0660
		user = postfix
		group = postfix
	}
	}

	protocol lda {
	  mail_plugins = \$mail_plugins sieve
	}

	protocol lmtp {
	  mail_plugins = \$mail_plugins sieve
	}

	plugin {
		sieve = ~/.dovecot.sieve
		sieve_default = /var/lib/dovecot/sieve/default.sieve
		#sieve_global_path = /var/lib/dovecot/sieve/default.sieve
		sieve_dir = ~/.sieve
		sieve_global_dir = /var/lib/dovecot/sieve/
	}
	" > /etc/dovecot/dovecot.conf

	# If using an old version of Dovecot, remove the ssl_dl line.
	case "$(dovecot --version)" in
		1|2.1*|2.2*) sed -i "/^ssl_dh/d" /etc/dovecot/dovecot.conf ;;
	esac
	mkdir /var/lib/dovecot/sieve/

	echo "require [\"fileinto\", \"mailbox\"];
	if header :contains \"X-Spam-Flag\" \"YES\"
		{
			fileinto \"Junk\";
		}" > /var/lib/dovecot/sieve/default.sieve

	grep -q "^vmail:" /etc/passwd || useradd vmail
	chown -R vmail:vmail /var/lib/dovecot
	sievec /var/lib/dovecot/sieve/default.sieve

	echo "Preparing user authentication..."
	grep -q nullok /etc/pam.d/dovecot ||
	echo "auth    required        pam_unix.so nullok
	account required        pam_unix.so" >> /etc/pam.d/dovecot
	# OpenDKIM

	# A lot of the big name email services, like Google, will automatically reject
	# as spam unfamiliar and unauthenticated email addresses. As in, the server
	# will flatly reject the email, not even delivering it to someone's Spam
	# folder.

	# OpenDKIM is a way to authenticate your email so you can send to such services
	# without a problem.

	# Create an OpenDKIM key in the proper place with proper permissions.
	echo "Generating OpenDKIM keys..."
	mkdir -p /etc/postfix/dkim
	opendkim-genkey -D /etc/postfix/dkim/ -d "$domain" -s "$subdom"
	chgrp opendkim /etc/postfix/dkim/*
	chmod g+r /etc/postfix/dkim/*
	
	# Generate the OpenDKIM info:
	echo "Configuring OpenDKIM..."
	grep -q "$domain" /etc/postfix/dkim/keytable 2>/dev/null ||
	echo "$subdom._domainkey.$domain $domain:$subdom:/etc/postfix/dkim/$subdom.private" >> /etc/postfix/dkim/keytable
	
	grep -q "$domain" /etc/postfix/dkim/signingtable 2>/dev/null ||
	echo "*@$domain $subdom._domainkey.$domain" >> /etc/postfix/dkim/signingtable

	grep -q "127.0.0.1" /etc/postfix/dkim/trustedhosts 2>/dev/null ||
		echo "127.0.0.1
	10.1.0.0/16
	1.2.3.4/24" >> /etc/postfix/dkim/trustedhosts

	# ...and source it from opendkim.conf
	grep -q "^KeyTable" /etc/opendkim.conf 2>/dev/null || echo "KeyTable file:/etc/postfix/dkim/keytable
	SigningTable refile:/etc/postfix/dkim/signingtable
	InternalHosts refile:/etc/postfix/dkim/trustedhosts" >> /etc/opendkim.conf
	
	sed -i '/^#Canonicalization/s/simple/relaxed\/simple/' /etc/opendkim.conf
	sed -i '/^#Canonicalization/s/^#//' /etc/opendkim.conf

	sed -e '/Socket/s/^#*/#/' -i /etc/opendkim.conf
	grep -q "^Socket\s*inet:12301@localhost" /etc/opendkim.conf || echo "Socket inet:12301@localhost" >> /etc/opendkim.conf

	# OpenDKIM daemon settings, removing previously activated socket.
	sed -i "/^SOCKET/d" /etc/default/opendkim && echo "SOCKET=\"inet:12301@localhost\"" >> /etc/default/opendkim

	# Here we add to postconf the needed settings for working with OpenDKIM
	echo "Configuring Postfix with OpenDKIM settings..."
	postconf -e "smtpd_sasl_security_options = noanonymous, noplaintext"
	postconf -e "smtpd_sasl_tls_security_options = noanonymous"
	postconf -e "myhostname = $maildomain"
	postconf -e "milter_default_action = accept"
	postconf -e "milter_protocol = 6"
	postconf -e "smtpd_milters = inet:localhost:12301"
	postconf -e "non_smtpd_milters = inet:localhost:12301"
	postconf -e "mailbox_command = /usr/lib/dovecot/deliver"
	
	# A fix for "Opendkim won't start: can't open PID file?", as specified here: https://serverfault.com/a/847442
	/lib/opendkim/opendkim.service.generate
	systemctl daemon-reload

	for x in spamassassin opendkim dovecot postfix; do
		printf "Restarting %s..." "$x"
		service "$x" restart && printf " ...done\\n"
	done

	
	service ufw disable
	service ufw stop
	
	pval="$(tr -d "\n" </etc/postfix/dkim/$subdom.txt | sed "s/k=rsa.* \"p=/k=rsa; p=/;s/\"\s*\"//;s/\"\s*).*//" | grep -o "p=.*")"
	dkimentry="$subdom._domainkey.$domain	TXT	v=DKIM1; k=rsa; $pval"
	dmarcentry="_dmarc.$domain	TXT	v=DMARC1; p=reject; rua=mailto:dmarc@$domain; fo=1"
	spfentry="@	TXT	v=spf1 mx a:$maildomain -all"

	useradd -m -G mail dmarc

	echo "$dkimentry
	$dmarcentry
	$spfentry" > "$HOME/dns_emailwizard"

	printf "\033[31m
	 _   _
	| \ | | _____      ___
	|  \| |/ _ \ \ /\ / (_)
	| |\  | (_) \ V  V / _
	|_| \_|\___/ \_/\_/ (_)\033[0m

	Add these three records to your DNS TXT records on either your registrar's site
	or your DNS server:
	\033[32m
	$dkimentry

	$dmarcentry

	$spfentry
	\033[0m
	NOTE: You may need to omit the \`.$domain\` portion at the beginning if
	inputting them in a registrar's web interface.

	Also, these are now saved to \033[34m~/dns_emailwizard\033[0m in case you want them in a file.

	Once you do that, you're done! Check the README for how to add users/accounts
	and how to log in.\n"
	
	DNS_RECORDS="Please check out the records in ~/dns_emailwizard for your registrar (DNS provider)"
}
certificates_setup(){
	certbot run -n --nginx --agree-tos -d $1,www.$1,mail.$1,www.mail.$1 -m  $2@$1  --redirect 
}
item_echo(){
	echo "$green + $red $1 $reset"
}	
renew_crontab(){
	SLEEPTIME=$(awk 'BEGIN{srand(); print int(rand()*(3600+1))}'); echo "0 0,12 * * * root sleep $SLEEPTIME && certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
}
terminal_output_summery(){
	item_echo "Nginx was installed as web service"
	item_echo "Config file is located at $NGINX_LOC/$NGINX_CUSTOMIZED_CONFIG_FILE_LOCATION"
	item_echo "Postfix was installed as email service"
	item_echo "First email account was created: $1"
	item_echo "DNS records of email server: ~/dns_emailwizard"	
}
verify_ports(){
	declare -a arr=("smtp" "pop3" "pop3s" "imap2" "imaps");
	declare -a arr2=("25" "110" "995" "143" "993");

	for i in {0..4}
	do
		service="${arr[$i]}"
		port="${arr2[$i]}"
		iptables -L | grep $service >> /dev/null
		if [ $? == 1 ]; then
			echo "Port $port is not open"
			echo "Opening up port $port ..."
			iptables -A INPUT -p tcp --dport $port -j ACCEPT
			iptables -L | grep $service >> /dev/null
			if [ $? == 1 ]; then
				echo "Error: port $port is still closed, script aborted, verify the system settings and try it again" | boxes -d peek
				exit 1
			fi
		fi
		echo "Port $port is open"
	done
}


run_script(){
percent=0
DATA=$(grep -w 80 /etc/services)
if [ $? -eq 0 ]
then
	apt update -q >> /dev/null 2>&1
        apt install -y -q boxes >> /dev/null 2>&1
        apt install -y -q whiptail >> /dev/null 2>&1

	#program start
	echo -e "		SAT HEROS\n Installation Script of Web and Email Server" | boxes -d cc
	if (whiptail --title "SAT HEROS: Installation of Web and Email Server" --yesno "Do you want to start?" 8 78); then
		echo "User selected Ok"
		echo "Installation started"	
	else
		echo "User selected Cancel"
		echo "Installation aborted"
		exit 0
	fi
	enviroment_preparation 
	#read domain name (DNS name) and assign it to the INPUT variable 
	input_box "domain"
	domain_validation $DOMAIN 
	web_service_setup $DOMAIN
	#Setting email server up
	DNS_RECORDS="Error: setup of the email server did not work"
	email_service_setup
	#read adminstrator name (DNS name) and assign it to the INPUT variable 
	input_box "user"
	PASSWORD=$(whiptail --passwordbox "please enter your secret password" 8 78 --title "password dialog" 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus == 0 ]; then
		echo "User selected Ok and entered Password"
	else
		echo "User selected Cancel."
	fi
	intial_user_account_setup $EMAIL_USER $PASSWORD
	echo $DOMAIN
	echo $EMAIL_USER
	certificates_setup $DOMAIN $EMAIL_USER
	renew_crontab
	verify_ports
	terminal_output_summery "$EMAIL_USER@$DOMAIN" | boxes -d javadoc
else
	echo "Port 80 is not open, open port for this session at first"
fi	
	
exit 0
	
}


##--------Governance--------##
if [ $(id -u) -eq 0 ]; then
	run_script
else
	echo "Only root may add a user to the system."
	exit 2
fi

















