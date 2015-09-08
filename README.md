nginx/apache virtualhost manager
===========

Bash scripts to easily (interactively) create or delete Apache and nginx virtual hosts on Debian/Ubuntu quickly.

## Installation ##

Download the script and run:

`
sudo chmod +x virtualhost.sh && sudo chmod +x virtualhost-nginx.sh && sudo cp virtualhost.sh /usr/local/bin/virtualhost && sudo cp virtualhost-nginx.sh /usr/local/bin/virtualhost-nginx
`

## nginx Usage ##

Basic usage:

        sudo virtualhost-nginx -a create
        sudo virtualhost-nginx -a delete
        virtualhost-nginx --help

Passing all parameters:

        sudo virtualhost-nginx -a create -d nginx.dev -p 80 -g www-data --octal 775 -o www-data --nginx /etc/nginx/ -w /var/www/nginx.dev/public_html/


## Apache Usage ##

Basic command line syntax:

    $ sudo sh /path/to/virtualhost.sh [create | delete] [domain] [optional host_dir]
    
With script installed on /usr/local/bin

    $ sudo virtualhost [create | delete] [domain] [optional host_dir]
    
### Apache Examples ###

to create a new virtual host:

    $ sudo virtualhost create mysite.dev
  
to create a new virtual host with custom directory name:

    $ sudo virtualhost create anothersite.dev my_dir
  
to delete a virtual host

    $ sudo virtualhost delete mysite.dev
  
to delete a virtual host with custom directory name:

    $ sudo virtualhost delete anothersite.dev my_dir

## Roadmap ##

* Add HHVM options
* Update Apache to match nginx syntax
* tweak nginx config
* add installer?
