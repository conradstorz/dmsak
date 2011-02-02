#!/bin/sh
#
# DMSAK - Drupal Multi-Site Admin Kit
# This script updates a Drupal module.
#
# Copyright 2009 António Maria Torre do Valle
# Released under the GNU General Public Licence (GPL): http://www.gnu.org/licenses/gpl-3.0.html
#
# This script is part of the Drupal Multi-Site Admin Kit (DMSAK).
# DMSAK is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# DMSAK is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with DMSAK. If not, see <http://www.gnu.org/licenses/>.
# 
#     Usage: update-module.sh [-d <path-to-drupal-dirs> [-v X] | -w <path-to-webs-dir>] [-N] <path-to-module-tarball>
#        Or: update-module.sh  [-N] [-W <website>] <path-to-module-tarball>
#
#   Example: update-module.sh -d /var/lib -v 6 -N module-6.x-1.10.tar.gz
#        Or: update-module.sh -W example.com 6 -N module-6.x-1.10.tar.gz
# Or simply: update-module.sh module-6.x-1.10.tar.gz
#
# This script assumes that Drupal folders are named "drupal-X" where X is the version number (5, 6 or 7).
#
# More info at: http://www.torvall.net

# Search for config file. First in the current working directory, then at the user's home and finally in /etc.
# If all fails, default values will be used.
if [ -e ./dmsak.cfg ]; then
	DMSAK_CONFIG=./dmsak.cfg
else
	if [ -e ~/dmsak.cfg ]; then
		DMSAK_CONFIG=~/dmsak.cfg
	else
		if [ -e /etc/dmsak.cfg ]; then
			DMSAK_CONFIG=/etc/dmsak.cfg
		else
			# Set reasonable values for the defaults.
			DRUPAL_VERSION="6"
			DRUPAL_DIR="/var/lib"
			WEBS_DIR="/var/www"
			BACKUP_DIR="/root"
			TEMP_DIR="/tmp"
			DB_HOST="localhost"
			DB_USER="root"
			DB_PASS=""
		fi
	fi
fi

# Include config file.
if [ "$DMSAK_CONFIG" ]; then
	. $DMSAK_CONFIG
fi

# Parse parameters.
WEB_URL=""
while getopts "d:v:w:W:Nh" flag
do
	case $flag in
		d)
			DRUPAL_DIR="$OPTARG"
			;;
		v)
			DRUPAL_VERSION="$OPTARG"
			;;
		w)
			WEBS_DIR="$OPTARG"
			;;
		W)
			WEB_URL="$OPTARG"
			;;
		N)
			NO_BACKUP="TRUE"
			;;
		h)
			HELP_REQUESTED="TRUE"
	esac
done

# Check if help was requested.
if [ "$HELP_REQUESTED" = "TRUE" ]; then
	echo 1>&2 "This script updates a Drupal module"
	echo 1>&2 "Copyright 2009 by António Maria Torre do Valle"
	echo 1>&2 "Released under the GNU General Public Licence (GPL)"
	echo 1>&2 "More info at: http://www.torvall.net"
	echo 1>&2 ""
	echo 1>&2 "Usage: $0 [-d <path-to-drupal-dirs>] [-w <path-to-webs-dir>] [-v X] [-N] <path-to-module-tarball>"
	echo 1>&2 "   Or: $0 [-N] [-W <website>] <path-to-module-tarball>"
	echo 1>&2 ""
	echo 1>&2 "Parameters:"
	echo 1>&2 "  -h  Shows this help message"
	echo 1>&2 "  -d  Location of base Drupal directories (default: $DRUPAL_DIR)"
	echo 1>&2 "  -w  Directory containing websites (default: $WEBS_DIR)"
	echo 1>&2 "  -v  Drupal version (5, 6 or 7, others still untested) (default: $DRUPAL_VERSION)"
	echo 1>&2 "  -W  Website to update (ex: example.com)"
	echo 1>&2 "  -N  Do not backup old module folder"
	echo 1>&2 "  <path-to-module-tarball> is the path to the package that contains the module to be installed (ex: module-6.x-1.10.tar.gz)"
	echo 1>&2 "  If the -W option is specified, parameters -d and -v will be ignored."
	echo 1>&2 "  Parameters -d, -w and -v are optional, and the configured values will be used by default. See the config file dmsak.cfg."
	echo 1>&2 ""
	echo 1>&2 "Example: $0 -d /var/lib -w /var/www -v 6 -N module-6.x-1.10.tar.gz"
	echo 1>&2 "     Or: $0 -W example.com module-6.x-1.10.tar.gz"
	exit 0
fi

# Reset argument position.
shift $((OPTIND-1)); OPTIND=1

# Get new module path (last argument).
NEW_MODULE_PATH="$@"
NEW_MODULE_FILENAME=`basename $NEW_MODULE_PATH`
SEPARATOR_POSITION=$((`expr index "$NEW_MODULE_FILENAME" "-"`-1))
MODULE_NAME=`expr substr $NEW_MODULE_FILENAME 1 $SEPARATOR_POSITION`

# Check command line parameters.
if [ "$WEB_URL" != "" ]; then
	# Check parameters to update module in web dir.
	if [ "$WEBS_DIR" = "" -o "$NEW_MODULE_PATH" = "" ]; then
		echo 1>&2 Usage: $0 -d /var/lib -w /var/www -v 6 -N module-6.x-1.10.tar.gz
		echo 1>&2    Or: $0 -W example.com module-6.x-1.10.tar.gz
		exit 127
	fi

	# Get the target folder and some others.
	WEB_BASE_DIR="$WEBS_DIR/$WEB_URL"
	MODULES_DIR="$WEB_BASE_DIR/sites/$WEB_URL/modules"
	MODULE_DIRECTORY="$MODULES_DIR/$MODULE_NAME"

	# Sanity checks.
	# Check if web directory exists.
	if [ ! -e $WEB_BASE_DIR  ]; then
		echo "Oops! Web directory $WEB_BASE_DIR does not exist. Aborting."
		exit 127
	fi

	SUCCESS_MESSAGE="Don't forget to run http://$WEB_URL/update.php."
else
	# Check parameters to update module in Drupal code base dir.
	if [ "$DRUPAL_VERSION" = "" -o "$DRUPAL_DIR" = "" -o "$NEW_MODULE_PATH" = "" ]; then
		echo 1>&2 Usage: $0 -d /var/lib -w /var/www -v 6 -N module-6.x-1.10.tar.gz
		echo 1>&2    Or: $0 -W example.com module-6.x-1.10.tar.gz
		exit 127
	fi

	# Get the target folder and some others.
	DRUPAL_BASE_DIR="$DRUPAL_DIR/drupal-$DRUPAL_VERSION"
	MODULES_DIR=$DRUPAL_BASE_DIR/sites/all/modules
	MODULE_DIRECTORY=$MODULES_DIR/$MODULE_NAME

	# Sanity checks.
	# Check if Drupal directory exists.
	if [ ! -e $DRUPAL_BASE_DIR  ]; then
		echo "Oops! Drupal directory $DRUPAL_BASE_DIR does not exist. Aborting."
		exit 127
	fi

	SUCCESS_MESSAGE="Don't forget to run update.php on all sites that use this module."
fi

# Check that the module directory is there.
if [ ! -e $MODULE_DIRECTORY  ]; then
	echo "Oops! Module directory not present at $MODULE_DIRECTORY. Aborting."
	exit 127
fi

# Backup data unless otherwise specified by user.
if [ ! "$NO_BACKUP" = "TRUE" ]; then
	MODULE_BACKUP_TARBALL=$BACKUP_DIR/$MODULE_NAME-`date +%Y%m%d%H%M`-backup.tar.gz
	echo "Backing up data..."
	tar zcf $MODULE_BACKUP_TARBALL -C $MODULES_DIR $MODULE_NAME
	echo "Backed up module folder to $MODULE_BACKUP_TARBALL."
else
	echo "-N option specified. Data will not be backed up."
fi

# Extract new package to $TEMP_DIR.
echo "Extracting $NEW_PACKAGE_TARBALL..."
tar zxf $NEW_MODULE_PATH -C $TEMP_DIR
echo "Module tarball extracted to $TEMP_DIR/$MODULE_NAME."

# Delete old module directory.
echo "Deleting old module folder..."
rm -r $MODULE_DIRECTORY
echo "$MODULE_DIRECTORY deleted."

# Move new module folder to destination.
echo "Moving new module's directory to final destination..."
mv $TEMP_DIR/$MODULE_NAME $MODULES_DIR
echo "Directory moved to $MODULES_DIR/$MODULE_NAME."

# Display some form of success message to the user.
echo
echo "All done."
echo $SUCCESS_MESSAGE

exit 0

