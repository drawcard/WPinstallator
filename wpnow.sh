#!/bin/bash -e

# install https://gist.github.com/xavierartot/61f7e6d7ab1e6318a1d0

# Check for missing dependencies
type wp >/dev/null 2>&1 || { echo >&2 "ERROR: This script requires wp-cli but it's not installed. Please visit https://make.wordpress.org/cli/handbook/installing/ and follow the installation instructions, then re-run this script."; exit 1; }
type apg >/dev/null 2>&1 || { echo >&2 "ERROR: This script requires apg but it's not installed. Run 'sudo apt-get install apg' to install and then re-run this script. Aborting."; exit 1; }

# Colors: https://gist.github.com/vratiu/9780109
black="[033[0;30m]"        # Black
red="[033[0;31m]"          # Red
green="[033[0;32m]"        # Green
yellow="[033[0;33m]"       # Yellow
blue="[033[0;34m]"         # Blue
purple="[033[0;35m]"       # Purple
cyan="[033[0;36m]"         # Cyan
white="[033[0;37m]"        # White

echo -e "To install in a subfolder, write the folder name. eg ~/www/path/to/wp/"
echo -e "Otherwise hit Enter to install in the current directory:"
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

echo -e "${yellow}Generating password... (this may take some time)${white}"
dbpass=`apg -a 1 -m 14 -n 1 -c cl_seed -M SNCL`
echo -e "${blue}* DB password ${dbpass} has been generated. ${white}"
echo -e "${blue}Run install? (y/n) ${white}"
read run

if [[ "$run" == n ]]; then
   exit
fi

# Set to Australian. Update for other countries.
wp core download --locale="en_AU"

echo "*** Please enter your MySQL Admin Password."
MYSQL=`which mysql`

Q1="CREATE DATABASE IF NOT EXISTS ${dbname};"
Q2="GRANT USAGE ON *.* TO ${dbuser}@localhost IDENTIFIED BY '${dbpass}';"
Q3="GRANT ALL PRIVILEGES ON ${dbname}.* TO ${dbuser}@localhost;"
Q4="FLUSH PRIVILEGES;"

SQL="${Q1}${Q2}${Q3}${Q4}"
$MYSQL -uroot -p -e "$SQL"

echo -e "${yellow}* MYSQL setup is complete. ${white}*"

echo "Running WP-CLI core config"
wp core config --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --extra-php <<PHP
// Enable debugging - logged to wp-content/debug.log
define( 'WP_DEBUG', true );
// Manage display of errors and warnings (true / false)
define( "WP_DEBUG_DISPLAY", false );
// Manage display of errors and warnings (PHP setting) (0 / 1)
@ini_set( "display_errors", 0 );
// Manage the storage of queries - this affects site performance (true / false) 
define( "SAVEQUERIES", false );
// Use dev versions of core JS and CSS files (true / false)
define( "SCRIPT_DEBUG", false );
// Unminify JS and CSS for extra debugging powers (true / false)
define( 'CONCATENATE_SCRIPTS', false );
PHP

echo -e "${blue}Site URL (without https://):${white}"
read siteurl

echo -e "${blue}Site title:${white}"
read sitetitle

echo -e "${blue}WP Admin username:${white}"
read adminuser

echo -e "${yellow}Generating password... (this may take some time)${white}"
adminpassword=`apg -a 1 -m 14 -n 1 -c cl_seed -E 0Ol1iI8B3vu\`\~\!\{\}\[\]\(\)\<\>\,\.\\\/\|\?\;\:\'\"`
echo -e "${blue}Admin password '$adminpassword' has been generated. ${white}"

echo -e "${blue}WP Admin email:${white}"
read adminemail

echo -e "${yellow}* Installing Wordpress... \n ${white}*"
wp core install --url="http://${siteurl}" --title="${sitetitle}" --admin_user="${adminuser}" --admin_password="${adminpassword}" --admin_email="${adminemail}"

echo -e "Write wpcli config. \n"
cat >> wp-cli.yml <<EOL
apache_modules:
   - mod_rewrite
EOL

# set pretty urls
wp rewrite structure '/%year%/%monthnum%/%postname%/' --hard
wp rewrite flush --hard

# install Elementor (needed to set up maintenance page below)
wp plugin install elementor --activate

# Update WordPress options

echo -e "${green}* Wordpress Setup Tasks ${white}"

echo -e "${yellow}Set up the basics...${white}"
wp option update blogdescription 'Welcome to our website'
wp option update blog_public 'on' # set to off to disable search engine crawling
wp option update admin_email '$adminemail'

echo -e "${yellow}Set up image sizes...${white}"
wp option update thumbnail_size_h '400'
wp option update thumbnail_size_w '400'
wp option update thumbnail_crop '0'
wp option update medium_size_h '0'
wp option update medium_size_w '800'
wp option update medium_large_size_h '0'
wp option update medium_large_size_w '1200'
wp option update large_size_h '0'
wp option update large_size_w '1600'
wp option update image_default_size 'medium'
wp_option_update image_default_align 'right'

echo -e "${yellow}Configure comment settings...${white}"
wp option update comment_moderation 'true'
wp option update default_comment_status 'closed'
wp option update comments_notify '1'
wp option update default_ping_status 'closed' 
wp option update default_pingback_flag '0'
wp option update close_comments_for_old_posts '1'

echo -e "${yellow}Remove default pages...${white}"
wp post delete $(wp post list --post_type='page' --format=ids) # remove 'hello world' page
wp post delete $(wp post list --post_type='post' --format=ids) # remove 'hello world' post
wp post create --post_type=page --post_title='Homepage' --post_content='Edit this page in Elementor to get started.' --post_status=private
wp post create --post_type=page --post_title='About' --post_content='Edit this page in Elementor to get started.' --post_status=private 
wp post create --post_type=page --post_title='Contact' --post_content='Edit this page in Elementor to get started.' --post_status=private
wp post create --post_type=page --post_title='Terms and Conditions' --post_content='Edit this page in Elementor to get started.' --post_status=private
wp post create --post_type=elementor_library --post_title='Under Maintenance' --post_content='This website is under maintenace - please visit again soon.' --post_status=publish

echo -e "${yellow}Update homepage settings...${white}"
wp option update page_on_front $(wp post list --post_type=page --pagename="homepage" --format=ids);
wp option update show_on_front 'page'

echo -e "${yellow}Update Elementor settings...${white}"
wp option update elementor_default_generic_fonts '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen-Sans,Ubuntu,Cantarell,"Helvetica Neue",sans-serif'
wp option update elementor_container_width '1200'

echo -e "${yellow}Flush permalinks...${white}"
wp rewrite flush --hard

echo -e "${yellow}Setup Elementor Hello base template...${white}"
wp theme install https://github.com/pojome/elementor-hello-theme/archive/master.zip --activate

echo -e "${yellow}Remove useless themes...${white}"
wp theme delete kubrick twentyten twentyeleven twentytwelve twentythirteen twentyfourteen twentyfifteen twentysixteen twentyseventeen twentyeighteen twentynineteen twentytwenty twentytwentyone twentytwentytwo twentytwentythree twentytwentyfour twentytwentyfive

echo -e "${yellow}Setup menu system...${white}"
wp menu create "Main Menu"
wp menu location assign main-menu menu-1

echo -e "${yellow}Add menu items...${white}"
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="homepage" --format=ids) --title="Home"
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="about" --format=ids)
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="contact" --format=ids)
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="terms-and-conditions" --format=ids) --parent-id=$(wp post list --post_type=page --pagename="about" --format=ids)

echo -e "${yellow}Remove useless plugins...${white}"
wp plugin delete akismet hello

echo -e "${yellow}Add useful plugins...${white}"
wp plugin install wp-cerber wordpress-seo health-check query-monitor

echo -e "${yellow}Add Pro plugins...${white}"
cp -r ~/wp-pro-plugins/* ./wp-content/wp-plugins

echo -e "${yellow}Activate plugins...${white}"
wp plugin activate --all

echo -e "${yellow}Licence Elementor Pro...${white}"
echo -e "${blue}* Please enter your Elementor Pro activation key (or Enter key to dismiss)${white}"
read -s elemkey
wp elementor-pro license activate ${elemkey}

echo -e "${yellow}Turn on 'Maintenance Mode'...${white}"
wp option update elementor_maintenance_mode_exclude_mode 'logged_in'
wp option update elementor_maintenance_mode_template_id $(wp post list --post_type="elementor_library" --format=ids);
wp option update elementor_maintenance_mode_mode 'coming_soon'

echo -e "${yellow}Licence WP DB Migrate Pro...${white}"
echo -e "${blue}* Please enter your WP DB Migrate Pro activation key (or Enter key to dismiss) ${white}"
read -s wpdbkey
cat >> wp-config.php <<EOL
    define( 'WPMDB_LICENCE', '${wpdbkey}' );
EOL

echo -e "${yellow}Update all plugins...${white}"
wp plugin update --all

echo -e "${yellow}Set .htaccess to protect sensitive files...${white}"
cat >> .htaccess <<EOL
    # Protect wp-config.php
<Files "wp-config.php">
    order allow,deny
    deny from all
</Files>
    # Protect debug log
<Files "debug.log">
    order allow,deny
    deny from all
</Files>
EOL

echo -e "${green}* \n The install process is complete!"
echo -e "Here are the credentials you need. Please store these somewhere safe. \n "

echo -e "${yellow}-------------------- "
echo -e "~~ WP LOGIN "
echo -e "Username: ${adminuser}"
echo -e "Password: ${adminpassword}"
echo -e "Admin email: ${adminemail}"
echo -e "~~ DATABASE \n"
echo -e "DB Name: ${dbname}"
echo -e "DB User: ${dbuser}"
echo -e "DB Pass: ${dbpass}"
echo -e "-------------------- \n"

echo -e "${green}You may now login at: ${siteurl}/wp-admin/${white}"
echo -e "${green}TIP: Run 'wp media regenerate' to apply preset dimensions to existing media files.\n ${white}"

