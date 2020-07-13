Pivotalzilla is a [Bugzilla](https://www.bugzilla.org/) extention that mirror the
changes made on bugzilla on [Pivotal Tracker](https://www.pivotaltracker.com/).

### Install

First you have to copy the file `Pivotalzilla/lib/Credentials.pm.template` to
`Pivotalzilla/lib/Credentials.pm`, and modify the content of `Credentials.pm`.

You have to replace `my api token` by the Pivotal Tracker API token (found your
  Profile page on Pivotal Tracker), `42` by your project id (you can find it in
  the url of your project on Pivotal Tracker: www.pivotaltracker.com/projects/PROJECT_ID_HERE/),
  and `127.0.0.1/bugzilla` by the url of your bugzilla server (look at the url
  of a bug on bugzilla, and keep only the begining `THI_URL/show_bug.cgi?id=42`)

Then you have to change the `loadExtention.sh` file, and replace `BUGZILLA_FILE`
variable by the link to the file were your Bugzilla server is installed.

You will probably need to restart the server service, if you use systemctl and
  httpd, you can uncomment the `systemctl stop httpd` and `systemctl start httpd`.

### Features

#### Create a new story on Pivotal Tracker

To link a bug to a story on Pivotal Tracker, you have to write `/pivotal create`
in the comment of your bug on Bugzilla. If the bug already exists on Bugzilla,
the comments will be send to Pivotal Tracker retroactively. If the bug is already
linked to a story, nothing will append. The story contains a link to the Bugzilla
bug in description.

#### Add a label on the Pivotall Tracker story

You can add a label on the Pivot Tracker story by writing `/pivotal label myLabel`
in a comment on Bugzilla. If the label contains special characters (spaces, points, ...)
you have to use `/pivotal label [my label 1.0]`. Adding a label that does not
already exists on Pivotal Tracker is not recommended.

#### Changing the bug status

When the bug status is changed on Bugzilla, the bug status is changed on Pivotal
Tracker accordingly. You can change the mapping of the status by editing the
`%satus_bugzilla_to_pivotal` hashmap in `Pivotalzilla/lib/Util.pm`.

#### Commenting

When you make a comment on a linked bug on Bugzilla, the comment is sent to the
story on Pivotal Tracker, with the author added.

The `/pivotal ---` commands are removed from the comment of Bugzilla and the
comments sent to Pivoral Tracker.

#### Corresponding status

You can change the mapped status on pivotal tracker by modifying the hashmap
`%satus_bugzilla_to_pivotal` in `lib/Utils.pm`.

#### Modify status on late linking

If you link the bug to a new story **after** it's creation, you can modify its
status depending on the current status. This can be configured by modifying the
`%changed_status_on_create` in `lib/Utils.pm`.
