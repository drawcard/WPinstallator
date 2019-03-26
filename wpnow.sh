#!/bin/bash -e

# install https://gist.github.com/xavierartot/61f7e6d7ab1e6318a1d0

# Check for missing dependencies
type wp >/dev/null 2>&1 || { echo >&2 "ERROR: This script requires wp-cli but it's not installed. Please visit https://make.wordpress.org/cli/handbook/installing/ and follow the installation instructions, then re-run this script."; exit 1; }
type apg >/dev/null 2>&1 || { echo >&2 "ERROR: This script requires apg but it's not installed. Run 'sudo apt-get install apg' to install and then re-run this script. Aborting."; exit 1; }

# Colours: https://stackoverflow.com/a/28938235
black="\033[0;30m"        # Black
red="\033[0;31m"          # Red
green="\033[0;32m"        # Green
yellow="\033[0;33m"       # Yellow
blue="\033[0;34m"         # Blue
purple="\033[0;35m"       # Purple
cyan="\033[0;36m"         # Cyan
white="\033[0;37m"        # White
nc="\033[0m"           # Colour off

# Symbols
tick="\xE2\x9C\x94"

# Exit notices
function exit_report {
echo -e "${green}${tick} The install process is complete!"
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

echo -e "${purple} You may now login at: ${siteurl}/wp-admin/${nc}"
echo -e "${yellow}TIP: Run 'wp media regenerate' to apply preset dimensions to existing media files.\n ${nc}"
}

echo -e "To install in a subfolder, write the folder name. eg ~/www/path/to/wp/"
echo -e "Otherwise hit Enter to install in the current directory:"
read folder

if [[ "$folder" != "" ]]; then
    mkdir $folder && cd $folder
else
    path_arg=""
fi

echo "======================="
echo "WP Now - Database Setup"
echo "======================="
sleep 1

echo -e "${yellow}Please enter a unique database name, eg. 'wp_clientname' (max 16 chars):${nc}"
read dbname
# Take the DB name and generate a wp username from it
dbuser=$(expr substr "${dbname}" 1 16) # Trim excess characters (no more than 16 allowed)
echo -e "${green}${tick} Database name generated.${nc}"

echo -e "${yellow}Generating password (this may take some time)...${nc}"
dbpass=$(apg -a 1 -m 14 -n 1 -c cl_seed -M SNCL -E 0Ol1iI8B3vu\`\~\!\{\}\[\]\(\)\<\>\,\.\\\/\|\?\;\:\'\"\+\%)
echo -e "${green}${tick} Database password has been generated.${nc}"

echo -e "${yellow}You will now be asked for your MySQL admin password to begin setting up the database. Continue? (Y/n)${nc}"
read run

if [[ "$run" == n ]]; then
   exit
fi

MYSQL=`which mysql`

Q1="CREATE DATABASE IF NOT EXISTS ${dbname};"
Q2="GRANT USAGE ON *.* TO ${dbuser}@localhost IDENTIFIED BY '${dbpass}';"
Q3="GRANT ALL PRIVILEGES ON ${dbname}.* TO ${dbuser}@localhost;"
Q4="FLUSH PRIVILEGES;"

SQL="${Q1}${Q2}${Q3}${Q4}"
$MYSQL -uroot -p -e "$SQL"

echo "=================="
echo "WP Now - CMS Setup"
echo "=================="
sleep 1

# Set to Australian. Update for other countries.
wp core download --locale="en_AU"

echo -e "${yellow}Site URL (without https://):${nc}"
read siteurl

echo -e "${yellow}Site title:${nc}"
read sitetitle

echo -e "${yellow}WP Admin username:${nc}"
read adminuser

echo -e "${yellow}Generating password... (this may take some time)${nc}"
adminpassword=$(apg -a 1 -m 14 -n 1 -c cl_seed -E 0Ol1iI8B3vu\`\~\!\{\}\[\]\(\)\<\>\,\.\\\/\|\?\;\:\'\")
echo -e "${green}${tick} Admin password '$adminpassword' has been generated. ${nc}"

echo -e "${yellow}WP Admin email:${nc}"
read adminemail

echo -e "${yellow}Enabling debug & development settings in wp-config.php ... \n ${nc}"
wp config create --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --extra-php <<PHP

// Debugging and development settings - review these settings before publishing to production.

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

echo -e "${yellow}Installing Wordpress & configuring wp-config.php ... \n ${nc}"
wp core install --url="http://${siteurl}" --title="${sitetitle}" --admin_user="${adminuser}" --admin_password="${adminpassword}" --admin_email="${adminemail}"

echo -e "${yellow}Set .htaccess to protect sensitive files...${nc}"
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

echo -e "${yellow}Writing wp-cli.yml config...${nc}"
cat >> wp-cli.yml <<EOL
apache_modules:
   - mod_rewrite
EOL

echo -e "${green}${tick} WordPress CMS has been successfully installed. ${nc}"
sleep 1

echo -e "${yellow}Would you like to run additional custom configurations, plugins, themes? 
Consult README.md for more information on what's installed and configured. 
Also read the script to see these options in detail. 
Otherwise, type 'n' if you'd like to have a blank WordPress install, & exit the script.(Y/n) ${nc}"
read run

if [[ "$run" == n ]]; then
exit_report
   exit
fi

echo "=========================="
echo "WP Now - Configure options"
echo "=========================="
sleep 1

echo -e "${yellow}Configure pretty permalinks...${nc}"
sleep 1
wp rewrite structure '/%year%/%monthnum%/%postname%/' --hard
wp rewrite flush --hard

# Update WordPress options
echo -e "${yellow}Configure the website title & set admin email to ${adminemail}... ${nc}"
sleep 1
wp option update blogdescription 'Welcome to our website'
wp option update blog_public 'on' # set to off to disable search engine crawling
wp option update admin_email '$adminemail'

echo -e "${yellow}Set up image sizes to 400x400-tn / 800-m / 1200-ml / 1600-l ...${nc}"
sleep 1
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
wp option update image_default_align 'right'

echo -e "${yellow}Turn off commenting by default to cut down on spam...${nc}"
sleep 1
wp option update comment_moderation 'true'
wp option update default_comment_status 'closed'
wp option update comments_notify '1'
wp option update default_ping_status 'closed' 
wp option update default_pingback_flag '0'
wp option update close_comments_for_old_posts '1'

echo -e "${yellow}Remove default pages and add useful starter pages (Home / About / Contact / Terms)...${nc}"
sleep 1
wp post delete $(wp post list --post_type='page' --format=ids) # remove 'hello world' page
wp post delete $(wp post list --post_type='post' --format=ids) # remove 'hello world' post
wp post create --post_type=page --post_title='Homepage' --post_content='Edit this page in Elementor to get started.' --post_status=private
wp post create --post_type=page --post_title='About' --post_content='Edit this page in Elementor to get started.' --post_status=private 
wp post create --post_type=page --post_title='Contact' --post_content='Edit this page in Elementor to get started.' --post_status=private
wp post create --post_type=page --post_title='Terms and Conditions' --post_content='Edit this page in Elementor to get started.' --post_status=private

echo -e "${yellow}Configure homepage to point to 'Homepage'...${nc}"
sleep 1
wp option update page_on_front $(wp post list --post_type=page --pagename="homepage" --format=ids);
wp option update show_on_front 'page'

echo -e "${yellow}Setup menu system...${nc}"
wp menu create "Main Menu"
wp menu location assign main-menu menu-1

echo -e "${yellow}Add menu items...${nc}"
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="homepage" --format=ids) --title="Home"
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="about" --format=ids)
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="contact" --format=ids)
wp menu item add-post main-menu $(wp post list --post_type=page --pagename="terms-and-conditions" --format=ids) --parent-id=$(wp post list --post_type=page --pagename="about" --format=ids)

echo -e "${yellow}Flush permalinks...${nc}"
sleep 1
wp rewrite flush --hard

echo -e "${yellow}Remove redundant plugins...${nc}"
wp plugin delete akismet hello

echo -e "${green}${tick} Configuration is complete.${nc}"
sleep 1

# Plugins to install
plugins="wp-cerber wordpress-seo health-check query-monitor"

echo -e "${yellow}Would you like to set up useful plugins? 
The plugins are: ${plugins} 
Consult README.md for more information. Also read the script to see these options in detail. 
Otherwise, type 'n' if you'd like to exit the script.(Y/n) ${nc}"
read run

if [[ "$run" == n ]]; then
exit_report
   exit
fi

echo "========================"
echo "WP Now - Install Plugins"
echo "========================"
sleep 1

echo -e "${yellow}Add useful plugins...${nc}"
wp plugin install ${plugins}

echo -e "${green}${tick} Plugin install complete.${nc}"
sleep 1

echo -e "${yellow}Would you like to set up Elementor page builder + Elementor Hello base theme? 
Consult README.md for more information. Also read the script to see these options in detail. 
Otherwise, type 'n' if you'd like to exit the script.(Y/n) ${nc}"
read run

if [[ "$run" == n ]]; then
exit_report
   exit
fi

echo "=========================="
echo "WP Now - Install Elementor"
echo "=========================="
sleep 1

echo -e "${yellow}Install plugin...${nc}"
sleep 1
wp plugin install elementor 

echo -e "${yellow}Configure plugin...${nc}"
sleep 1
wp option update elementor_default_generic_fonts '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen-Sans,Ubuntu,Cantarell,"Helvetica Neue",sans-serif'
wp option update elementor_container_width '1200'

echo -e "${yellow}Install & Set up 'Elementor Hello' base template...${nc}"
wp theme install https://github.com/pojome/elementor-hello-theme/archive/master.zip --activate

echo -e "${yellow}Remove other default themes...${nc}"
wp theme delete kubrick twentyten twentyeleven twentytwelve twentythirteen twentyfourteen twentyfifteen twentysixteen twentyseventeen twentyeighteen twentynineteen twentytwenty twentytwentyone twentytwentytwo twentytwentythree twentytwentyfour twentytwentyfive

echo -e "${green}${tick} Configuration is complete. Go to ${siteurl}/wp-admin/options.php to see additional changes.${nc}"
sleep 1

echo -e "${yellow}Would you like to set up Elementor Pro & enable Maintenance Mode placeholder page? 
A copy of the Pro plugin must be available in ~/.wp-pro-plugins/. 
Consult README.md for more information. Also read the script to see these options in detail. 
Otherwise, type 'n' if you'd like to exit the script.(Y/n) ${nc}"
read run

if [[ "$run" == n ]]; then
exit_report
   exit
fi

echo "=============================="
echo "WP Now - Install Elementor Pro"
echo "=============================="
sleep 1

echo -e "${yellow}Add plugin...${nc}"
sleep 1
cp -r ~/.wp-pro-plugins/elementor-pro/ ./wp-content/plugins/

echo -e "${yellow}Activate & update plugin...${nc}"
sleep 1
wp plugin activate elementor-pro 
wp plugin update elementor-pro

echo -e "${yellow}Licence Elementor Pro...${nc}"
sleep 1
echo -e "${blue}Please enter your Elementor Pro activation key: ${nc}"
read -s elemkey
wp elementor-pro license activate ${elemkey}

echo -e "${yellow}Turn on 'Maintenance Mode'...${nc}"
sleep 1
wp post create --post_type=elementor_library --post_title='Under Maintenance' --post_content='This website is under maintenace - please visit again soon.' --post_status=publish
wp option update elementor_maintenance_mode_exclude_mode 'logged_in'
wp option update elementor_maintenance_mode_template_id $(wp post list --post_type="elementor_library" --format=ids);
wp option update elementor_maintenance_mode_mode 'coming_soon'

echo -e "${yellow}Flush permalinks...${nc}"
sleep 1
wp rewrite flush --hard

echo -e "${green}${tick} Elementor Pro & Maintenance Mode configured."
sleep 1

echo -e "${yellow}Would you like to set up WP DB Migrate Pro? 
A copy of the Pro plugin must be available in ~/.wp-pro-plugins/. 
Consult README.md for more information. Also read the script to see these options in detail. 
Otherwise, type 'n' if you'd like to exit the script.(Y/n) ${nc}"
read run

if [[ "$run" == n ]]; then
exit_report
   exit
fi

echo "=================================="
echo "WP Now - Install WP DB Migrate Pro"
echo "=================================="
sleep 1

echo -e "${yellow}Add plugin...${nc}"
cp -r ~/.wp-pro-plugins/wp-migrate-* ./wp-content/plugins/

echo -e "${yellow}Activate & update plugin...${nc}"
# Activate all plugin folders starting with wp-migrate-*
for i in $(ls -d wp-migrate-*); do wp plugin activate ${i%%/}; done
for i in $(ls -d wp-migrate-*); do wp plugin update ${i%%/}; done

echo -e "${yellow}Licence WP DB Migrate Pro...${nc}"
echo -e "${blue}* Please enter your WP DB Migrate Pro activation key: ${nc}"
read -s wpdbkey
cat >> wp-config.php <<EOL
    define( 'WPMDB_LICENCE', '${wpdbkey}' );
EOL

echo -e "${green}${tick} WP DB Migrate Pro installed and configured."
sleep 1

#The script is done
exit_report


