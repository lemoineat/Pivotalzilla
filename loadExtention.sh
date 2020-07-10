#!/bin/sh
# Copy to the server files the exetention and update the server.

systemctl stop httpd

BUGZILLA_FILE='/srv/http/bugzilla'

cp Pivotalzilla/Extension.pm $BUGZILLA_FILE/extensions/Pivotalzilla/Extension.pm
cp Pivotalzilla/lib/Credentials.pm $BUGZILLA_FILE/extensions/Pivotalzilla/lib/Credentials.pm
cp Pivotalzilla/lib/Util.pm $BUGZILLA_FILE/extensions/Pivotalzilla/lib/Util.pm

cd $BUGZILLA_FILE/
perl checksetup.pl
systemctl start httpd
