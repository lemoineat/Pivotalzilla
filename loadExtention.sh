#!/bin/sh
# Copy to the server files the exetention and update the server.

systemctl stop httpd

BUGZILLA_FILE='/srv/http/bugzilla'

cp Extension.pm $BUGZILLA_FILE/extensions/Pivotalzilla/Extension.pm
cp lib/Credentials.pm $BUGZILLA_FILE/extensions/Pivotalzilla/lib/Credentials.pm
cp lib/Util.pm $BUGZILLA_FILE/extensions/Pivotalzilla/lib/Util.pm
cp lib/Config.pm $BUGZILLA_FILE/extensions/Pivotalzilla/lib/Config.pm
cp Config.pm $BUGZILLA_FILE/extensions/Pivotalzilla/Config.pm

cd $BUGZILLA_FILE/
perl checksetup.pl
systemctl start httpd
