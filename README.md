Pivotalzilla is a [Bugzilla](https://www.bugzilla.org/) extention that mirror the
changes made on bugzilla on [Pivotal Tracker](https://www.pivotaltracker.com/).

### Install

First you have to copy the file `lib/Credentials.pm.template` to
`lib/Credentials.pm`, and modify the content of `Credentials.pm`.

You have to replace `my api token` by the Pivotal Tracker API token (found your
  Profile page on Pivotal Tracker), `42` by your project id (you can find it in
  the url of your project on Pivotal Tracker: www.pivotaltracker.com/projects/PROJECT_ID_HERE/),
  and `127.0.0.1/bugzilla` by the url of your bugzilla server (look at the url
  of a bug on bugzilla, and keep only the begining `THI_URL/show_bug.cgi?id=42`)

Place this repository (name `Pivotzilla`, it's important), in the `extensions`
  file of your bugzilla install, and run `perl checksetup.pl` (in the root of the
  bugzilla file). The Switch module is needed, so you may need to run `sudo perl install-module.pl Switch`

You may need to restart bugzilla.



You will probably need to restart the server service, if you use systemctl and
  httpd, you can uncomment the `systemctl stop httpd` and `systemctl start httpd`.

### Features

#### Create a new story on Pivotal Tracker

To link a bug to a story on Pivotal Tracker, you have to write `/pivotal create`
in the comment of your bug on Bugzilla. If the bug already exists on Bugzilla,
the comments will be send to Pivotal Tracker retroactively. If the bug is already
linked to a story, it won't create another story. The story contains a link to the
Bugzilla bug in description and a link to the story is added in a comment of the bug
in bugzilla. You can add labels after `/pivotal create`. If you
want to add a label with special characters, you have to put the label between `[]`.
`/pivotal create test bugzilla [my cool label!]` create a story and add the labels
`test`, `bugzilla` and `my cool label!`. Adding a label that does not
already exists on Pivotal Tracker is not recommended.

#### Add a label on the Pivotall Tracker story

You can add a label on the Pivot Tracker story by writing `/pivotal label` followed
by the labels in a comment on Bugzilla. If the label contains special characters
(spaces, points, ...), put the label between `[]`. `/pivotal create test bugzilla [my cool label!]` add the labels `test`, `bugzilla` and `my cool label!`. Adding a label
that does not already exists on Pivotal Tracker is not recommended.

#### Changing the bug status

When the bug status is changed on Bugzilla, the bug status is changed on Pivotal
Tracker accordingly. You can change the mapping of the status by editing the
`%satus_bugzilla_to_pivotal` hashmap in `Pivotalzilla/lib/Util.pm`.

If the new status is in %create_on_status in the lib/Config.pm file, a story is create like if '/pivotal create'
was written in the comments.

#### Commenting

When you make a comment on a linked bug on Bugzilla, the comment is sent to the
story on Pivotal Tracker, with the author added.

~~The `/pivotal ---` commands are removed from the comment of Bugzilla and the
comments sent to Pivoral Tracker.~~

#### Error

If a line starting by `/pivotal` is not followeb by a valid command, an error
will be print in the comments of the bug. The error messages can be removed
with `/pivotal clear`

#### Corresponding status

You can change the mapped status on pivotal tracker by modifying the hashmap
`%satus_bugzilla_to_pivotal` in `lib/Config.pm` (**the one in the lib/ directory**).

A default value can be set for status not found in `%satus_bugzilla_to_pivotal`,
with `$default_pivotal_status`.

#### Modify status on creation

You can modify its status depending on the current status. This can be configured by modifying the `%changed_status_on_create` in `lib/Config.pm`.

#### pivotalzibot

You can avoid sending back messages sent by pivotalzibot by setting to `1` `$pivotalzibot_compatible` in `lib/config.pm`

### TODO

Check the issu with the breaklines. For now, we don't edit/replace the comments. 
