#!/bin/bash
### Set default parameters
action=$1
domain=$2
rootdir=$3
#owner=$(who am i | awk '{print $1}')
owner=$4
group=$5
email='info@mindsharelabs.com'
sitesEnable='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'
sitesAvailabledomain=$sitesAvailable$domain.conf

### don't modify from here unless you know what you are doing ####
 
if [ "$(whoami)" != 'root' ]; then
  	echo "You don't have permission to run $0 as non-root user. Use root."
		exit 1;
fi
 
if [ "$action" != 'create' ] && [ "$action" != 'delete' ] 
	then
		echo "Please specify an action (create or delete) -- case sensitive"
		exit 1;
fi
 
while [ "$domain" == ""  ]
do
	echo -e "Please provide domain, e.g. domain.dev"
	read  domain
done
 
if [ "$action" == 'create' ] 
	then

		if [ "$rootdir" == "" ]; then
			owner='www-data'
			group='www-data'
		fi

		if [ "$rootdir" == "" ]; then
			#rootdir=${domain//./}
			echo "Pease provide www directory relative to / root."
			exit 1;
		fi

		### check if domain already exists
		if [ -e $sitesAvailabledomain ]; then
			echo -e 'This domain already exists.\nPlease try another.'
			exit;
		fi
 
		### check if directory exists or not
		if ! [ -d "$rootdir" ]; then
			### create the directory
			mkdir "$rootdir"
			### give permission to root dir
			chmod -v 755 "$rootdir"
			chown -hRv $owner:$group "$rootdir" 
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > "$rootdir/phpinfo.php"
			then
				echo "ERROR: Not able to write to file "$rootdir"/phpinfo.php. Please check permissions."
				exit;
			else
				echo "Added content to "$rootdir"/phpinfo.php."
			fi
		fi
 
		### create virtual host rules file
		if ! echo "
		<VirtualHost *:80>
			ServerAdmin $email
			ServerName $domain
			ServerAlias $domain
			DocumentRoot "\"$rootdir"\"
			<Directory />
				AllowOverride All
			</Directory>
			<Directory "\"$rootdir"\" >
				Options FollowSymLinks MultiViews
				Options -Indexes 
				AllowOverride all
				Require all granted
			</Directory>
			ErrorLog /var/log/apache2/$domain-error.log
			LogLevel error
			CustomLog /var/log/apache2/$domain-access.log combined
		</VirtualHost>" > $sitesAvailabledomain
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
		a2ensite $domain
 
		### restart Apache
		/etc/init.d/apache2 reload
 
		### show the finished message
		echo -e "Complete! \nYou now have a new Apache2 Virtual Host. \nYour new host is: http://"$domain" \nAnd it is located at $rootdir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailabledomain ]; then
			echo -e 'This domain does not exist.\nTry another?'
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			a2dissite $domain
	 
			### restart Apache
			/etc/init.d/apache2 reload

			### Delete virtual host rules files
			rm -v $sitesAvailabledomain
		fi

		if [ "$rootdir" == ""  ]; then
			echo -e "To delete the document root please enter the absolute path, leave blank (press enter) to preserve files."
			read  rootdir
		fi
 
		### check if directory exists or not
		if [ -d "$rootdir" ]; then
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
