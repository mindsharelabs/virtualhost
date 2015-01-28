#!/bin/bash

# ---------------------------------------------------------------------------
# virtualhost-nginx.sh - Manage nginx virtual hosts

# Copyright 2015, Mindshare Labs, <info@mindsharelabs.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

# Revision history:
# 2015-01-28 misc updates for SSL setups and Digital Ocean PHP5-fpm installs, added sslport option, HHVM example, forward secrecy
# 2014-12-08 Created by new_script ver. 3.3
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}
VERSION="0.1.2"

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"

fakeDomain='example.dev'
defaultWebroot='/var/www/'
defaultPort="80"
defaultSSLPort="443"
defaultServer="false"
defaultGroup="www-data"
defaultPerms=755
defaultNginxPath="/etc/nginx/"
defaultOwner=$(whoami | awk '{print $1}')

clean_up() { # Perform pre-exit housekeeping
	return
}

error_exit() {
	echo -e "${PROGNAME}: ${1:-"Unknown Error"}" >&2
	clean_up
	exit 1
}

graceful_exit() {
	clean_up
	exit
}

signal_exit() { # Handle trapped signals
	case $1 in
		INT)
			error_exit $COL_RED"Program interrupted by user"$COL_RESET ;;
		TERM)
        	echo -e "\n"$PROGNAME": "$COL_RED"Program terminated"$COL_RESET >&2
			graceful_exit ;;
		*)
			error_exit $COL_RED"$PROGNAME: Terminating on unknown signal"$COL_RESET ;;
	esac
}

usage() {
	echo -e "Usage: $PROGNAME [-h|--help] [-a|--action create|delete] [-d|--domain $fakeDomain]"
}

program_title() {
	echo
	echo -e $COL_BLUE"================================"$COL_RESET
	echo -e $COL_CYAN"   nginx virtual host manager"$COL_RESET
	echo -e $COL_BLUE"================================"$COL_RESET
	echo
}

help_message() {
	program_title
	cat <<- _EOF_
	$PROGNAME ver. $VERSION

	$(usage)

	Options:
	-h, --help	Display this help message and exit.
	-a, --action	[create | delete] Create or delete a virtual host.
	-d, --domain 	Domain host name.
	-o, --owner 	Web server username. Default ${defaultOwner}
	-g, --group 	Web server group. Default ${defaultGroup}
	-p, --port 	Web server port. Default ${defaultPort}
	-s, --sslport 	Web server SSL port. Default ${defaultSSLPort}
	-w, --webroot 	Web server root path. Default ${defaultWebroot}${fakeDomain}
	--default 	[true | false] Set this host to be the default_server. Default ${defaultServer}
	--octal 	Web server octal permissions for folders. Default ${defaultPerms}
	--nginx 	Web server path. Default ${defaultNginxPath}

	NOTE: You must be the superuser to run this script.

	_EOF_
	return
}

# Trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT" INT

# Parse command-line
while [[ -n $1 ]]; do
	case $1 in
		-h | --help)
			help_message;
			graceful_exit ;;
		-a | --action)
			shift;
			create="$1";
			action=${1,,} # convert variale to lowercase, bash 4.0+
			;;
		-d | --domain)
			shift;
			create="$1"
			domain=${1,,};;
		-w | --webroot)
			shift;
			create="$1"
			webroot=$1;;
		-o | --owner)
			shift;
			create="$1"
			owner=$1;;
		-g | --group)
			shift;
			create="$1"
			group=$1;;
		-p | --port)
			shift;
			#echo "Port: $1";
			create="$1" ;
			port=$1;;
		-s | --sslport)
			shift;
			#echo "SSL Port: $1";
			create="$1" ;
			sslport=$1;;
		--octal)
			shift;
			create="$1" ;
			octal=$1;;
		--default)
			shift;
			create="$1" ;
			ds=$1;;
		--nginx)
			shift;
			#echo "nginx path: $1";
			create="$1" ;
			nginxPath=$1;;
		-* | --*)
			usage
			error_exit "Unknown option $1" ;;
		*)
			echo "Argument $1 to process..." ;;
	esac
	shift
done

# Check for root UID
if [[ $(id -u) != 0 ]]; then
	error_exit $COL_RED"You must be the superuser to run $PROGNAME."$COL_RESET
fi

# Main logic

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo -e $COL_RED"No action was specified, try one of these:"$COL_RESET
		echo -e $PROGNAME" -a "$COL_CYAN"create"$COL_RESET
		echo -e $PROGNAME" -a "$COL_CYAN"delete"$COL_RESET
		exit 1;
	else
		program_title
fi

if [ "$nginxPath" == "" ]; then
	read -p "Specify your nginx install path or hit enter for default [$defaultNginxPath]: " nginxPath
	nginxPath=${nginxPath:-$defaultNginxPath}
	echo -e "Using nginx path: "$COL_BLUE$nginxPath$COL_RESET"\n"
fi
if [ ! -d "$nginxPath" ]; then
	echo -e $COL_RED"An invalid nginx path was specified.\nExiting..."$COL_RESET
		exit 1;
fi

sitesEnable=$nginxPath"sites-enabled/"
sitesAvailable=$nginxPath"sites-available/"

#########################
#    DELETION ROUTINE	#
#########################
if [ "$action" == "delete"  ]; then

	echo -e "Select a virtual host to "$COL_RED"delete"$COL_RESET": "
	shopt -s nullglob # causes the array to be empty if there are no matched
	hostsAvail=($sitesAvailable*)
	PS3='Enter the number for the virtual host to delete: '
	hostsAvail=("${hostsAvail[@]}" "Exit without deleting any virtual hosts.")
	select FILENAME in "${hostsAvail[@]}"
	do
		case $FILENAME in
			"Exit without deleting any virtual hosts.")
				echo -e "\n"$PROGNAME": "$COL_YELLOW"Terminated by user."$COL_RESET >&2
				graceful_exit
			;;
			*)
				strlen=${#sitesAvailable}
				domain=${FILENAME:$strlen} # trim the path from the domain
				echo
				echo -e "Virtual host selected for "$COL_RED"deletion"$COL_RESET": "$COL_CYAN"$domain"$COL_RESET
				echo
				break
			;;
		esac
	done


	if [ "$webroot" == "" ]; then
		read -p "Specify the web root path for $domain or hit enter for default [$defaultWebroot$domain]: " webroot
		webroot=${webroot:-$defaultWebroot$domain}
		echo -e "Web root: "$COL_BLUE$webroot$COL_RESET"\n"
	fi

	### check whether domain already exists
	if ! [ -f "$FILENAME" ]; then
	echo -e $FILENAME
		echo -e $COL_RED'The virtual host "'$domain'" does not exist.\nExiting...'$COL_RESET
		graceful_exit
	else
		### Delete domain in /etc/hosts
		echo -e $COL_YELLOW"Removing $domain from /etc/hosts"$COL_RESET"\n"
		newhost=${domain//./\\.}
		sed -i "/$newhost/d" /etc/hosts

		### disable website, if enabled
		if [ -e "$sitesEnable$domain" ]; then
			echo -e $COL_YELLOW"Disabling virtual host: "$COL_RESET$domain
			rm -v "$sitesEnable$domain"
			echo
		fi

		### restart Nginx
		echo -e $COL_YELLOW"Restarting nginx"$COL_RESET
		service nginx restart

		### Delete virtual host rules files
		rm -v $FILENAME
		echo
	fi

	### check if directory exists or not
	if [ -d $webroot ]; then
		echo -e $COL_RED"Really delete all files under $webroot? (y/n)"$COL_RESET
		read deldir

		if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
			### Delete the directory
			rm -rv "$webroot"
			echo -e $COL_RED'Web root directory deleted.'$COL_RESET
		else
			echo -e 'Web root directory preserved.'
		fi
	else
		echo -e $COL_YELLOW'Web root directory was not found. Ignored.'$COL_RESET
	fi

	### show the finished message
	echo
	echo -e $COL_GREEN"Success!$COL_RESET The virtual host for "$COL_CYAN$domain$COL_RESET" was deleted."
	echo
	graceful_exit
fi


#########################
#   CREATION ROUTINE	#
#########################
if [ "$action" == "create"  ]; then

	while [ "$domain" == ""  ]
	do
		echo -e "Virtual host domain to $action (e.g. $fakeDomain):"
		read  domain
	done
	echo -e "Virtual host selected for "$COL_GREEN"creation"$COL_RESET": "$COL_CYAN"$domain"$COL_RESET

	### check if domain already exists
	if [ -e $sitesAvailable$domain ]; then
		echo -e $COL_RED'This domain already exists. Perhaps you wanted to delete it?\nExiting...'$COL_RESET
		graceful_exit
	fi

	if [ "$ds" == ""  ]; then
		read -p "Use this virtual host as the server default? [$defaultServer]: " ds
		ds=${ds:-$defaultServer}
		echo -e "default_server: "$COL_BLUE$ds$COL_RESET
		
		if [ "$ds" == "true"  ]; then
			ds="default_server"
		else
			ds=""
		fi
	fi

	if [ "$port" == ""  ]; then
		read -p "Please provide a port or press enter for default [$defaultPort]: " port
		port=${port:-$defaultPort}
		echo -e "Using port: "$COL_BLUE$port$COL_RESET
	fi
	
	
	if [ "$sslport" == ""  ]; then
		read -p "Please provide an SSL port or press enter for default [$defaultSSLPort]: " sslport
		sslport=${sslport:-$defaultSSLPort}
		echo -e "Using SSL port: "$COL_BLUE$sslport$COL_RESET
	fi

	if [ "$octal" == ""  ]; then
		read -p "Please provide a value for folder permissions or press enter for default [$defaultPerms]: " octal
		octal=${octal:-$defaultPerms}
		echo -e "Using "$COL_BLUE$octal$COL_RESET" for chmod"
	fi

	if [ "$owner" == "" ]; then
		read -p "Enter a user to set as the owner for files inside the web root [$defaultOwner]: " owner
		owner=${owner:-$defaultOwner}
		echo -e "Owner: "$COL_BLUE$owner$COL_RESET
	fi

	if [ "$group" == "" ]; then
		read -p "Enter a group to set for files inside the web root [$defaultGroup]: " group
		group=${group:-$defaultGroup}
		echo -e "Group: "$COL_BLUE$group$COL_RESET
	fi

#	if [ "$webroot" == "" ]; then
#		webroot=${domain//./}
#	fi
	if [ "$webroot" == "" ]; then
		read -p "Specify the web root path for $domain or hit enter for default [$defaultWebroot$domain/public_html/]: " webroot
		webroot=${webroot:-$defaultWebroot$domain/public_html/}
		echo -e "Web root: "$COL_BLUE$webroot$COL_RESET"\n"
	fi

	### check if directory exists or not
	if ! [ -d $webroot ]; then
		### create the directory
		mkdir -vp $webroot
		### give permission to root dir
		chmod -v $octal $webroot
		### write test file in the new domain dir
		if ! echo "<?php echo phpinfo(); ?>" > $webroot"phpinfo.php"
		then
			echo $COL_RED"ERROR:"$COL_RESET" Not able to write in file "$webroot"phpinfo.php. Please check permissions."
			exit;
		else
			echo "Added content to "$webroot"phpinfo.php."
		fi
	fi

	### create virtual host rules file
	if ! echo "server {
	listen $port $ds; # listen for ipv4; this line is default and implied
	listen [::]:$port $ds ipv6only=on; # listen for ipv6

	# SSL configuration
	#listen $sslport $ds ssl;
	#listen [::]:$sslport $ds ssl ipv6only=on;

	# configure Forward Secrecy, see: http://goo.gl/563XnK
	#ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	#ssl_prefer_server_ciphers on;
	#ssl_ciphers \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS\";
	
	root $webroot;
	index index.php index.html index.htm;
	server_name $domain;
	
	access_log /var/log/nginx/access_$domain.log;
	error_log /var/log/nginx/error_$domain.log;
	
	#ssl_certificate /etc/ssl/$domain.crt;
	#ssl_certificate_key /etc/ssl/$domain.key;
	#if (\$scheme = \"http\") {
	#	return 301 https://\$server_name\$request_uri;
	#}

	# serve static files directly
	location ~* \.(jpg|jpeg|gif|css|png|js|ico|html)$ {
		access_log off;
		expires max;
	}

	# removes trailing slashes (prevents SEO duplicate content issues)
	#if (!-d \$request_filename) {
	#	rewrite ^/(.+)/\$ /\$1 permanent;
	#}

	# unless the request is for a valid file (image, js, css, etc.), send to bootstrap
	if (!-e \$request_filename) {
		rewrite ^/(.*)\$ /index.php?/\$1 last;
		break;
	}

	# removes trailing 'index' from all controllers
	if (\$request_uri ~* index/?\$) {
		rewrite ^/(.*)/index/?\$ /\$1 permanent;
	}

	# catch all
	error_page 404 /index.php;

	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)\$; # comment out for Digital Ocean php5-fpm
		fastcgi_pass 127.0.0.1:9000; # comment out for Digital Ocean php5-fpm
		#try_files \$uri =404; # uncomment for Digital Ocean php5-fpm
		#fastcgi_pass unix:/var/run/php5-fpm.sock; # uncomment for Digital Ocean php5-fpm
		
		fastcgi_index index.php;
		include fastcgi_params;
	}
	
	# HHVM example configuration
	#location ~ \.(hh|php)$ {
	#	fastcgi_keep_conn on;
	#	fastcgi_pass   127.0.0.1:9000;
	#	fastcgi_index  index.php;
	#	fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
	#	include        fastcgi_params;
	#}

	location ~ /\.ht {
		deny all;
	}

}" > $sitesAvailable$domain
	then
		echo -e $COL_RED"ERROR creating $sitesAvailable$domain file\nExiting..."$COL_RESET
		graceful_exit
	else
		echo -e '\nVirtual host created.\n'
	fi

	### Add domain in /etc/hosts
	if ! echo "127.0.0.1	$domain" >> /etc/hosts
	then
		echo $COL_RED"ERROR: Not able write to /etc/hosts\nExiting..."$COL_RESET
		graceful_exit
	else
		echo -e "Host added to /etc/hosts file \n"
	fi

	### set ownership
	chown -R $owner:$group "$webroot"

	### enable website
	ln -s $sitesAvailable$domain $sitesEnable$domain

	### restart Nginx
	service nginx restart

	### show the finished message
	echo -e $COL_GREEN"Complete! "$COL_RESET"Your new nginx virtual host is ready:\nURL: "$COL_CYAN"http://"$domain$COL_RESET"\nWeb root: $COL_BLUE$webroot$COL_RESET\nConfig file: $COL_BLUE$sitesAvailable$domain$COL_RESET"
	echo
	exit;
fi

graceful_exit
