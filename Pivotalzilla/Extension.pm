# Copyright(C) 2020 Lemoine Automation Technologies
#
# This file is part of Pivotalzilla.
#
# Pivotalzilla is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Foobar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <https://www.gnu.org/licenses/>.

package Bugzilla::Extension::Pivotalzilla;

use 5.10.1;
use strict;
use warnings;
use Bugzilla::Comment;
use Bugzilla::Constants;

use parent qw(Bugzilla::Extension);

use Bugzilla::Extension::Pivotalzilla::Util;

our $VERSION = '0.01';

## This hook is called after the creation of a hook.
sub bug_end_of_create {
    my ($self, $args) = @_;
    my $bug = $args->{bug};
    my $id = %$bug{bug_id};
    if (check_create($id)){
      new_pivotal_story($bug);
    }
}

## This hook is called after updating a bug (creation included)
sub bug_end_of_update {
    my ($self, $args) = @_;
    my $bug = $args->{bug};
    my $id = $bug->bug_id;
    my $old_bug = $args->{old_bug};
    my $story_id = $bug->{'cf_pivotal_story_id'};
    if ($story_id){ # Hey, this doesn't work with the first story ! bad
      # Post new comments
      my $comments = $bug->{added_comments};
      foreach my $comment (@$comments){
        my $comment_body = $comment->body;
        my $author = $comment->author->identity;
        my $text = "$comment_body\n\nFrom $author on Bugzilla";
        post_comment($story_id, $text);
      }
      # Update status
      if ($bug->{bug_status} ne $old_bug->{bug_status}){
        my $status = $satus_bugzilla_to_pivotal{$bug->{bug_status}};
        modify_status($story_id, $status);
      }
      my @labels = get_labels($id);
      foreach my $label (@labels){
        add_label($story_id, $label);
      }
    }else{
      my $id = %$bug{bug_id};
      if (check_create($id)){
        if (defined $changed_status_on_create{$bug->{bug_status}}){
          $bug->set_bug_status($changed_status_on_create{$bug->{bug_status}}, {});
        }
        my $id_pivotal = new_pivotal_story($bug);
        $bug->{added_comments} = []; # Avoid duplicat comments
        $bug->update(); # save the changes in the database
      }
    }
}

## Hook called when the db is updated (install or upgrade of bugzilla)
## Add a field cf_pivotal_story_id to the bugs.
sub install_update_db{
  my $field = new Bugzilla::Field({ name => 'cf_pivotal_story_id' });
  return if $field;

  $field = Bugzilla::Field->create({
      name        => 'pivotal_story_id',
      description => 'Story #',
      type        => FIELD_TYPE_INTEGER,        # From list in Constants.pm
      enter_bug   => 0,
      buglist     => 0,
      custom      => 1,
  });
}

sub bug_fields {
  my ($self, $args) = @_;
  my $fields = $args->{fields};
  push(@$fields, 'cf_pivotal_story_id');
}

sub bug_columns {
  my ($self, $args) = @_;
  my $columns = $args->{'columns'};
  push(@$columns, 'cf_pivotal_story_id');
}

__PACKAGE__->NAME;
