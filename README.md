# WP Now!

Shell script to install the latest version of WordPress with WPCLI. Right now!

**This is heavily opinionated. Fork and edit to your needs.**

## Features (wp-cli & apg required)
- Creates MySQL database.
- Automatic installation of WordPress.
- Write wpconfig with debugging features (switched off except for logging to wp-content/debug.log)
- Add wp-cli.yml config.
- Add rewrite structure
- Update WordPress options
- Generate htaccess
- Cleanup & delete default WP stuff that is not needed
- Install Elementor Pro & WP DB Migrate Pro
- Configure stuff for Elementor

## Setup
```bash
sudo apt install apg # installs Auto Password Generator dependency
git clone https://github.com/drawcard/wpnow/ ~/.wpnow
echo -e "\n alias wpnow='bash ~/.wpnow/wpnow.sh' # WP Now! script" >> ~/.bashrc
source ~/.bashrc
# Navigate to the website folder you want to install and run `wpnow`
```

