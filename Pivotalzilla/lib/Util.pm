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


package Bugzilla::Extension::Pivotalzilla::Util;

use 5.10.1;
use strict;
use warnings;
use Bugzilla::Comment;
use Bugzilla::Constants;
use HTTP::Request ();
use JSON;
use LWP::UserAgent;
use Bugzilla::Extension::Pivotalzilla::Credentials;

use parent qw(Exporter);
our @EXPORT = qw(
  check_create
  get_labels
  new_pivotal_story
  get_bug_description
  get_story
  create_story
  modify_status
  post_comment
  add_label
  delete_story
  %satus_bugzilla_to_pivotal
  %changed_status_on_create
);

my $ua = LWP::UserAgent->new();
my $headers_r = ['X-TrackerToken' => $CONFIG{'token'}];
my $headers_w = ['X-TrackerToken' => $CONFIG{'token'},
                 'Content-Type' => 'application/json'];


## Map the bugzilla status to the pivotal tracker status
our %satus_bugzilla_to_pivotal = (
  'UNCONFIRMED' => 'unstarted',
  'CONFIRMED' => 'started',
  'IN_PROGRESS' => 'started',
  'RESOLVED' => 'delivered',
  'VERIFIED' => 'accepted',
);

## When the bug is linked with pivotal create, the hashmap is used to
## change the status to another one automaticaly.
our %changed_status_on_create = (
  'UNCONFIRMED' => 'CONFIRMED',
  'CONFIRMED' => undef,
  'IN_PROGRESS' => undef,
  'RESOLVED' => undef,
  'VERIFIED' => undef,
);


## Check is the bug contains a comments with the string '/pivotal create' inside.
## Those comments are deleted and replaced by the comment without '/pivotal
## create'
## Args:
##    $id_bug: the id of the bug
## Ret:
##    $count: the number of occurence of '/pivotal create' (can be use as a
##            boolean)
sub check_create {
  my ($id_bug,) = @_;
  my $count = 0;

  # List the content of every comments of bug.
  my @comments = Bugzilla::Comment->match({bug_id => $id_bug});
  foreach my $array (@comments){
    foreach my $comment (@$array){
      my $val = $comment->body;
      my $old_count = $count;
      while ($val =~ s/ *\/pivotal create\n?//){
        $count++;
      }
      if ($old_count != $count){ # if the comment is modified
        $comment->remove_from_db();
        my $creation_comment = {
          'thetext' => $val,
          'bug_id' => $id_bug,
        };
        Bugzilla::Comment->create($creation_comment);
      }
    }
  }
  return $count;
}

## List all the label added with '/pivotal label foo' inside comments.
## Those comments are deleted and replaced by the comment without '/pivotal
## create'
## Args:
##    $id_bug: the id of the bug
## Ret:
##    @labels: string[], the list of the labels to add to the pivotal story
sub get_labels {
  my ($id_bug,) = @_;
  my @labels = ();

  # List the content of every comments of bug.
  my @comments = Bugzilla::Comment->match({bug_id => $id_bug});
  foreach my $array (@comments){
    foreach my $comment (@$array){
      my $text = $comment->body;
      while ($text =~ s/ *\/pivotal label *\[(.*?)\]\n?//){
        push @labels, $1;
      }
      while ($text =~ s/ *\/pivotal label *(\w*)\n?//){
        push @labels, $1;
      }
      $comment->remove_from_db();
      my $creation_comment = {
        'thetext' => $text,
        'bug_id' => $id_bug,
      };
      Bugzilla::Comment->create($creation_comment);
    }
  }
  return @labels;
}

## Create a story on pivotal tracker
## Args:
##    $bug: ref of the bug to link to the story
## Ret:
##    $id_pivotal: int, the id of the story
sub new_pivotal_story{
  my ($bug,) = @_;
  my $id = %$bug{bug_id};

  my @labels = get_labels($id); # This function update the description, so it
                                # has before we send the new story.
  my $name = $bug->{short_desc};
  my $link_to_bugzilla = "$CONFIG{bugzilla_url}/show_bug.cgi?id=$id\n";
  my $description = 'link to bugzilla: ' . $link_to_bugzilla . get_bug_description($id);
  my $status = $satus_bugzilla_to_pivotal{$bug->{bug_status}};
  my $id_pivotal = create_story($name, $id, $description, $status);
  $bug->{'cf_pivotal_story_id'} = $id_pivotal;
  foreach my $label (@labels){
    add_label($id_pivotal, $label);
  }

  my $comments_tmp = Bugzilla::Comment->match({bug_id => $id});
  my @comments = @$comments_tmp[1 .. $#$comments_tmp];
  foreach my $comment (@comments){
    my $comment_body = $comment->body;
    my $author = $comment->author->identity;
    my $text = "$comment_body\n\nFrom $author on Bugzilla";
    post_comment($id_pivotal, $text);
  }
  return $id_pivotal;

}

## Return the description of the bug. It's the first comment (which exists, cf src)
## We add the author of the bug at the end of the description.
## Args:
##    $id_bug: the id of the bug
## Ret:
##    $description: str, the description of the bug
sub get_bug_description {
  my ($id_bug,) = @_;
  my $count = 0;

  # List the content of every comments of bug.
  my @comments = Bugzilla::Comment->match({bug_id => $id_bug});
  my $first_comment = $comments[0]->[0];

  my $comment_body = $first_comment->body;
  my $author = $first_comment->author->identity;
  my $text = "$comment_body\n\nFrom $author on Bugzilla";
  return $text;
}

## Get a story from pivotal tracker.
## Args:
##    $story_id: the id of the story
## Ret:
##    $story: the hashmap of the story
sub get_story {
  my ($story_id, ) = @_;
  my $url = "https://www.pivotaltracker.com/services/v5/projects/$CONFIG{project_id}/stories/$story_id";
  my $r = HTTP::Request->new('GET', $url, $headers_r );
  my $res = $ua->request($r);

  #print Dumper($res);
  my $story = decode_json($res->{_content});
  #print Dumper($story);
  return $story;
}

## Create a story on pivotal tracker.
## Args:
##    $name: string, name of the story
##    $id: int, id of the bug on bugzilla
##    $description: string: description of the story
##    $status: value of %satus_bugzilla_to_pivotal, status of the bug
## Ret:
##    $id: int, the id of the story
sub create_story {
  my ($name, $id, $description, $status,) = @_;
  my $url = "https://www.pivotaltracker.com/services/v5/projects/$CONFIG{project_id}/stories";
  my $data = {
    'current_state' => 'started',
    'name' => "Bug $id: $name",
    'description' => $description,
    'story_type' => 'bug',
    'current_state' => $status,
  };
  my $r = HTTP::Request->new('POST', $url, $headers_w, encode_json($data));
  my $res = $ua->request($r);
  my $pivotal_id = decode_json($res->{_content})->{id};
  return $pivotal_id;
}

## Modify the status of a story on pivotal tracker.
## Args:
##    $story_id: int, id of the story
##    $status: value of %satus_bugzilla_to_pivotal, status of the bug
sub modify_status {
  my ($story_id, $status,) = @_;
  my $url = "https://www.pivotaltracker.com/services/v5/projects/$CONFIG{project_id}/stories/$story_id";
  my $data = {
    'current_state' => $status,
  };
  my $r = HTTP::Request->new('PUT', $url, $headers_w, encode_json($data));
  my $res = $ua->request($r);
  my $id = decode_json($res->{_content})->{id};
}

## Post a comment on a story on pivotal tracker.
## Args:
##    $story_id: int, id of the story
##    $comment: string: comment
## Ret:
##    $id: int, the id of the comment
sub post_comment {
  my ($story_id, $comment,) = @_;
  my $url = "https://www.pivotaltracker.com/services/v5/projects/$CONFIG{project_id}/stories/$story_id/comments";
  while ($comment =~ s/ *\/pivotal label *\[(.*?)\]\n?//){} # remove pivotalzilla commands
  while ($comment =~ s/ *\/pivotal label *(\w*)\n?//){}
  my $data = {
    'text' => $comment,
  };
  my $r = HTTP::Request->new('POST', $url, $headers_w, encode_json($data));
  my $res = $ua->request($r);
  my $id = decode_json($res->{_content})->{id};
  return $id;
}

## Add a label on a story on pivotal tracker.
## If the label doesn't exists, it appears to be created, but the documentation
## is unclear about it, might be undefined behavior.
## Args:
##    $story_id: int, id of the story
##    $label: $label, name of the label (it has to exist on pivotal)
## Ret:
##    $id: int, the id of the label
sub add_label {
  my ($story_id, $label,) = @_;
  my $url = "https://www.pivotaltracker.com/services/v5/projects/$CONFIG{project_id}/stories/$story_id/labels";
  my $data = {
    'name' => $label,
  };
  my $r = HTTP::Request->new('POST', $url, $headers_w, encode_json($data));
  my $res = $ua->request($r);
  my $id = decode_json($res->{_content})->{id};
  return $id;
}

## Delete a story on pivotal tracker.
## Args:
##    $id: int, id of the story to remove
sub delete_story {
  my ($id,) = @_;
  my $url = "https://www.pivotaltracker.com/services/v5/projects/$CONFIG{project_id}/stories/$id";
  my $r = HTTP::Request->new('DELETE', $url, $headers_w);
  my $res = $ua->request($r);
}

1;
