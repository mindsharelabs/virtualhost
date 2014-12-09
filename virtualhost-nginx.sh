#!/bin/bash

# ---------------------------------------------------------------------------
# virtualhost-nginx.sh - Manage nginx virtual hosts

# Copyright 2014, Mindshare Labs, <info@mindsharelabs.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

# Usage: virtualhost-nginx.sh [-h|--help] [-h|--help] [-a|--action create] [-o|--owner www-data]

# Revision history:
# 2014-12-08 Created by new_script ver. 3.3
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}
VERSION="0.1"

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"

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
			echo -e $COL_RED"\n$PROGNAME: Program terminated"$COL_RESET >&2
			graceful_exit ;;
		*)
			error_exit $COL_RED"$PROGNAME: Terminating on unknown signal"$COL_RESET ;;
	esac
}

usage() {
	echo -e "Usage: $PROGNAME [-h|--help] [-a|--action create|delete] [-d|--domain example.dev]"
}

help_message() {
	echo
	echo -e $COL_BLUE"============================="$COL_RESET
	echo -e $COL_CYAN" Manage nginx virtual hosts"$COL_RESET
	echo -e $COL_BLUE"============================="$COL_RESET
	cat <<- _EOF_
	$PROGNAME ver. $VERSION

  $(usage)

  Options:
  -h, --help	Display this help message and exit.
  -a, --action	[create | delete] Create or delete a virtual host.
  -o, --owner www-data  Web server user
    Where 'www-data' is the Default user.

  NOTE: You must be the superuser to run this script.

	_EOF_
	return
}

# Trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT" INT

# Check for root UID
if [[ $(id -u) != 0 ]]; then
	error_exit "You must be the superuser to run $0."
fi

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
		-p | --port)
			shift;
			#echo "Port: $1";
			create="$1" ;
			port=$1;;
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

# Main logic

defaultWebroot='/var/www/'
defaultPort="80"
defaultGroup="www-data"

if [ "$nginxPath" == "" ]; then
	nginxPath="/etc/nginx/"
fi

sitesEnable="$nginxPath/sites-enabled/"
sitesAvailable="$nginxPath/sites-available/"

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo "Spcify an action --action [create | delete]"
		exit 1;
fi

while [ "$domain" == ""  ]
do
	echo -e "Virtual host domain to $action (e.g. domain.dev):"
	read  domain
done

if [ "$action" == "create"  ]; then
	if [ "$port" == ""  ]; then
		read -p "Please provide a port [$defaultPort]: " port
		port=${port:-$defaultPort}
		echo $port
	fi

	if [ "$owner" == "" ]; then
		owner=$(whoami | awk '{print $1}')
		echo 'No owner given, setting file ownership to: '$owner
	fi

	if [ "$group" == "" ]; then
		group=$defaultGroup
		echo 'No group given, setting group ownership to: '$group
	fi
fi

if [ "$webroot" == "" ]; then
	webroot=${domain//./}
fi

if [ "$action" == 'create' ]
	then
		### check if domain already exists
		if [ -e $sitesAvailable$domain ]; then
			echo -e 'This domain already exists.\nPlease Perhaps you wanted to delete it?'
			graceful_exit
		fi

		### check if directory exists or not
		if ! [ -d $userDir$webroot ]; then
			### create the directory
			mkdir $userDir$webroot
			### give permission to root dir
			chmod 755 $userDir$webroot
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > $userDir$webroot/phpinfo.php
			then
				echo "ERROR: Not able to write in file "$userDir"/"$webroot"/phpinfo.php. Please check permissions."
				exit;
			else
				echo "Added content to "$userDir$webroot"/phpinfo.php."
			fi
		fi

		### create virtual host rules file
		if ! echo "server {
	listen   80;
	root $userDir$webroot;
	index index.php index.html index.htm;
	server_name $domain;

	# serve static files directly
	location ~* \.(jpg|jpeg|gif|css|png|js|ico|html)$ {
		access_log off;
		expires max;
	}

	# removes trailing slashes (prevents SEO duplicate content issues)
	if (!-d \$request_filename) {
		rewrite ^/(.+)/\$ /\$1 permanent;
	}

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
		fastcgi_split_path_info ^(.+\.php)(/.+)\$;
		fastcgi_pass 127.0.0.1:9000;
		fastcgi_index index.php;
		include fastcgi_params;
	}

	location ~ /\.ht {
		deny all;
	}

}" > $sitesAvailable$domain
		then
			echo -e "ERROR creating $sitesAvailabledomain file"
			exit;
		else
			echo -e '\nNew Virtual Host Created\n'
		fi

		### Add domain in /etc/hosts
		if ! echo "127.0.0.1	$domain" >> /etc/hosts
		then
			echo "ERROR: Not able write to /etc/hosts"
			exit;
		else
			echo -e "Host added to /etc/hosts file \n"
		fi

		if [ "$owner" == ""  ]; then
			chown -R $(whoami):$(whoami) "$rootdir"
		else
			chown -R $owner:$group "$rootdir"
		fi

		### enable website
		ln -s $sitesAvailable$domain $sitesEnable$domain

		### restart Nginx
		service nginx restart

		### show the finished message
		echo -e "Complete! \nYou now have a new nginx Virtual Host. \nYour new host is: http://"$domain" \nAnd it is located at $rootdir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailable$domain ]; then
			echo -e $COL_RED'The virtual host "'$domain'" does not exist.'$COL_RESET'\nExiting...'
			graceful_exit
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			rm $sitesEnable$domain

			### restart Nginx
			service nginx restart

			### Delete virtual host rules files
			rm $sitesAvailable$domain
		fi

		### check if directory exists or not
		if [ -d $userDir$webroot ]; then
			echo -e "Really delete all files under $rootdir? (y/n)"
			read deldir

			if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
				### Delete the directory
				rm -rv "$rootdir"
				echo -e 'Directory deleted.'
			else
				echo -e 'Host directory preserved.'
			fi
		else
			echo -e 'Host directory not found. Ignored.'
		fi

		### show the finished message
		echo -e "Complete!\nYou just removed Virtual Host "$domain
		exit 0;
fi

graceful_exit
