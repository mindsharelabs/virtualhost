Apache/NginX Virtualhost Manager Script
===========

Bash Scripts to easily create or delete Apache or NginX virtual hosts on Debian/Ubuntu quickly.

## Installation ##

1. Download the script
2. Apply permission to execute:

        $ sudo chmod +x virtualhost.sh
  
3. Optional: if you want to use the script globally, then you need to copy the file to your /usr/local/bin directory, is better
if you copy it without the .sh extension:

        $ sudo cp virtualhost.sh /usr/local/bin/virtualhost

## Usage ##

Basic command line syntax:

    $ sudo sh /path/to/virtualhost.sh [create | delete] [domain] [optional host_dir]
    
With script installed on /usr/local/bin

    $ sudo virtualhost [create | delete] [domain] [optional host_dir]
    

### Examples ###

to create a new virtual host:

    $ sudo virtualhost create mysite.dev
  
to create a new virtual host with custom directory name:

    $ sudo virtualhost create anothersite.dev my_dir
  
to delete a virtual host

    $ sudo virtualhost delete mysite.dev
  
to delete a virtual host with custom directory name:

    $ sudo virtualhost delete anothersite.dev my_dir
