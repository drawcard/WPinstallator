#!/bin/bash -e

# install https://gist.github.com/xavierartot/61f7e6d7ab1e6318a1d0

# Check wp-cli installed
type wp >/dev/null 2>&1 || { echo >&2 "This script requires wp-cli but it's not installed.  Aborting."; exit 1; }

# colors
blue="\033[34m"
red="\033[1;31m"
green="\033[32m"
white="\033[37m"
yellow="\033[33m"

echo -e "To install in a subfolder, write the folder name.\n"
echo -e "Otherwise leave empty to install in root:"
read folder

if [[ "$folder" != "" ]]; then
    mkdir $folder && cd $folder
else
    path_arg=""
fi

echo "============================================"
echo "WordPress Install Script"
echo "============================================"

echo -e "${blue}* Please enter a unique database name, eg. 'wp_clientname': ${white}"
read dbname
# Take the DB name and generate a wp username from it
dbuser=$(expr substr "${dbname}" 1 16) # Trim excess characters (no more than 16 allowed)
echo -e "${blue}* DB user ${dbuser} has been generated from DB name.${white}"
# Randomly generate a 12 character password
dbpass=`date +%s | sha256sum | base64 | head -c 12`
echo -e "${blue}* DB password ${dbpass} has been generated. ${white}"
echo -e "${blue}Run install? (y/n) ${white}"
read run

if [[ "$run" == n ]]; then
   exit
fi

# Set to Australian. Update for other countries.
wp core download --locale="en_AU"

echo "Creating MYSQL stuff. MySQL admin password required."

MYSQL=`which mysql`

Q1="CREATE DATABASE IF NOT EXISTS $dbname;"
Q2="GRANT USAGE ON *.* TO $dbuser@localhost IDENTIFIED BY '$dbpass';"
Q3="GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@localhost;"
Q4="FLUSH PRIVILEGES;"

SQL="${Q1}${Q2}${Q3}${Q4}"
$MYSQL -uroot -p -e "$SQL"

echo -e "${green}* MYSQL done :) \n ${white}*"

echo "Running WP-CLI core config"
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass --extra-php <<PHP
define( 'WP_DEBUG', true );
// Force display of errors and warnings
define( "WP_DEBUG_DISPLAY", true );
@ini_set( "display_errors", 1 );
// Save Queries - set this to true if this is required (may impact site performance)
define( "SAVEQUERIES", false );
// Use dev versions of core JS and CSS files (set to true if you are modifying these core files)
define( "SCRIPT_DEBUG", false );
PHP

echo -e "${blue}Site URL (without https://):${white}"
read siteurl

echo -e "${blue}Site title:${white}"
read sitetitle

echo -e "${blue}WP Admin username:${white}"
read adminuser

adminpassword=`date +%s | sha256sum | base64 | head -c 12`
echo -e "${blue}Admin password '$adminpassword' has been generated. ${white}"

echo -e "${blue}WP Admin email:${white}"
read adminemail

echo -e "Running WP-CLI core install"
wp core install --url="http://$siteurl" --title="$sitetitle" --admin_user="$adminuser" --admin_password="$adminpassword" --admin_email="$adminemail"

echo -e "${green}* WP core install done :) \n ${white}*"


echo -e "Write wpcli config. \n"
cat >> wp-cli.yml <<EOL
apache_modules:
   - mod_rewrite
EOL

# set pretty urls
wp rewrite structure '/%year%/%monthnum%/%postname%/' --hard
wp rewrite flush --hard

# Update WordPress options

    # General Setup
wp option update blogname '$sitetitle'
wp option update blogdescription 'Welcome to the website of $sitetitle'
wp option update blog_public 'on' # set to off to disable search engine crawling
wp option update admin_email '$adminemail'
wp post delete $(wp post list --post_type='page' --format=ids) # remove 'hello world' page
wp post delete $(wp post list --post_type='post' --format=ids) # remove 'hello world' post

    # Media
wp option update thumbnail_size_w '400'
wp option update thumbnail_size_h '400'
wp option update thumbnail_crop '0'
wp option update medium_size_w '800'
wp option update medium_size_h '0'
wp option update large_size_w '1600'
wp option update large_size_h '0'
wp option update image_default_size 'medium'
image_default_align 'right'
wp media regenerate # regenerate any existing files

    # Comments
wp option update comment_moderation 'true'
wp option update default_comment_status 'closed'
wp option update comments_notify '1'
wp option update default_ping_status 'closed' 
wp option update default_pingback_flag '0'
wp option update close_comments_for_old_posts '1'

    # Default pages
wp post create --post_type=draft --post_title='Homepage' --post_content='Edit this page in Elementor to get started.' --post_status=publish
wp post create --post_type=draft --post_title='About' --post_content='Edit this page in Elementor to get started.' --post_status=publish 
wp post create --post_type=draft --post_title='Contact' --post_content='Edit this page in Elementor to get started.' --post_status=publish
wp post create --post_type=draft --post_title='Terms and Conditions' --post_content='Edit this page in Elementor to get started.' --post_status=publish
wp post create --post_type=elementor_library --post_title='Under Maintenance' --post_content='This website is under maintenace - please visit again soon.' --post_status=publish

    # Reading
wp option update page_on_front $(wp post list --post_type=page --pagename="homepage" --format=ids);
wp option update show_on_front 'page'

# generate htaccess
wp rewrite flush --hard

# setup elementor hello theme
wp theme install https://github.com/pojome/elementor-hello-theme/archive/master.zip --activate

# remove other themes
wp theme delete kubrick twentyten twentyeleven twentytwelve twentythirteen twentyfourteen twentyfifteen twentysixteen twentyseventeen twentyeighteen twentynineteen twentytwenty twentytwentyone twentytwentytwo twentytwentythree twentytwentyfour twentytwentyfive

# delete OOTB plugins
wp plugin delete akismet hello

# add free plugins
wp plugin install elementor wp-cerber 

# Grab 'pro' plugins from another directory and set up
cp -r ~/wp-pro-plugins ./wp-content/wp-plugins

# Activate all plugins
wp plugin activate --all

# Activate Elementor Pro
echo -e "${blue}* Please enter your Elementor Pro activation key (or Enter key to dismiss)${white}"
read elemkey
wp elementor-pro license activate $elemkey

# Elementor options setting
wp option update elementor_maintenance_mode_exclude_mode 'logged_in'
wp option update elementor_maintenance_mode_template_id $(wp post list --post_type="elementor_library" --format=ids);
wp option update elementor_maintenance_mode_mode 'coming_soon'

# Activate WP DB Migrate Pro
echo -e "${blue}* Please enter your WP DB Migrate Pro activation key (or Enter key to dismiss) ${white}"
read wpdbkey
cat >> wp-config.php <<EOL
    define( 'WPMDB_LICENCE', '$wpdbkey' );
EOL

# Update pro plugins
wp plugin update --all

echo -e "${green}* \n WP install finished! \n "
echo -e "Here are the credentials you need. Please store these somewhere safe. \n "
echo -e "${yellow}-------------------- \n"
echo -e "~~ WP LOGIN \n"
echo -e "Username: ${adminuser} \n"
echo -e "Password: ${adminpassword} \n"
echo -e "Admin email: ${adminemail} \n"
echo -e "~~ DATABASE \n"
echo -e "DB Name: ${dbname} \n"
echo -e "DB User: ${dbuser} \n"
echo -e "DB Pass: ${dbpass} \n"
echo -e "-------------------- \n"

echo -e "${green}You may now login at: ${siteurl}/wp-admin/ \n ${white}"
