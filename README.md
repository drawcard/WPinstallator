# WP Now!

Shell script to install the latest version of WordPress with WPCLI. Right now!

## Features (wp-cli required)
- Creates MySQL database.
- Automatic installation of WordPress.
- Write wpconfig with ``` define( 'WP_DEBUG', true );
// Force display of errors and warnings
define( "WP_DEBUG_DISPLAY", true );
@ini_set( "display_errors", 1 );
// Enable Save Queries
define( "SAVEQUERIES", true );
// Use dev versions of core JS and CSS files (only needed if you are modifying these core files)
define( "SCRIPT_DEBUG", true ); ```

- Add wp-cli.yml config.
- Add rewrite structure
- Update WordPress options
- Generate htaccess
- Cleanup & delete default WP stuff that is not needed
- Install Elementor Pro & WP DB Migrate Pro
- Configure stuff for Elementor

## Run the script

```bash
git clone https://github.com/drawcard/wpnow/ ~/.wpnow
echo -e "\n alias installwp='bash ~/.wpnow/wpnow.sh' # WP Install script" >> ~/.bashrc
source ~/.bashrc
# Navigate to the website folder you want to install and run installwp
```

