# Copyright(C) 2020 Lemoine Automation Technologies
#
# This file is part of Trackerzilla.
#
# Trackerzilla is free software: you can redistribute it and/or modify
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


package Bugzilla::Extension::Trackerzilla::Util;

use 5.10.1;
use strict;
use warnings;
use Bugzilla::Comment;
use Bugzilla::Constants;
use HTTP::Request ();
use JSON;
use LWP::UserAgent;
use Bugzilla::Extension::Trackerzilla::Credentials;
use Bugzilla::Extension::Trackerzilla::Config;
use Switch;
use Data::Dumper;


use parent qw(Exporter);
our @EXPORT = qw(
  read_commands
  new_pivotal_story
  get_bug_description
  get_story
  create_story
  modify_status
  post_comment
  add_label
  delete_story
  remove_error
  %CONFIG
  %create_on_status
);

my $ua = LWP::UserAgent->new();
my $headers_r = ['X-TrackerToken' => $CONFIG{'token'}];
my $headers_w = ['X-TrackerToken' => $CONFIG{'token'},
                 'Content-Type' => 'application/json'];


## List all the commands in the comments in parameters.
## Args:
##    $commnents: a ref of the array of comments.
##    $id_bug: int, the id of the bug.
## Ret:
##    $map: hashmap reference,
##    {
##      create: bool, if `/pivotal create` entered
##      clear: bool, if `/pivotal clear` entered
##      labels: array ref, list of label to add (strings),
##      new_comments: array ref, list of comments to add,
##      error_comments: array ref, list of comments to add because of error.,
##    };
sub read_commands {
  my ($comments_ref, $id_bug,) = @_;
  my @labels = ();
  my @new_comments = ();
  my @error_comments = ();
  my $clear = 0;
  my $create = 0;


  # List the content of every comments of bug.
  my @comments = @$comments_ref;

  foreach my $comment (@comments){
    my $text = $comment->body;
    my @lines = ();
    foreach my $line(split('\n', $text)){
      my $old_line = $line;
      if ($line !~ s/^\/pivotal//){
        push(@lines, $line);
        next;
      }
      my @args = split(' ', $line);
      if (!@args){
        my $error = {
         'thetext' => "PIVOTAL ERROR: $old_line\nNo command entered",
         'bug_id' => $id_bug,
        };
        push(@error_comments, $error);
      }else{
        switch($args[0]){
          case 'create' {
            $create = 1;
            my $arg_line = join(' ', @args[1..$#args]);
            my @matches = ($arg_line =~ /\[([^\[\]]+)\]|(\w+)/g);
            foreach my $label (@matches){
              if (defined $label){
                push(@labels, $label);
              }
            }
          }case 'label' {
            my $arg_line = join(' ', @args[1..$#args]);
            my @matches = ($arg_line =~ /\[([^\[\]]+)\]|(\w+)/g);
            foreach my $label (@matches){
              if (defined $label){
                push(@labels, $label);
              }
            }
          }case 'clear' {
            $clear = 1;
            if ($#args > 1){
              my $error = {
                'thetext' => "PIVOTAL ERROR: $old_line\nclear takes no parameters, parameters ignored.",
                'bug_id' => $id_bug,
              };
              push(@error_comments, $error);
            }
          }else{
            my $error = {
              'thetext' => "PIVOTAL ERROR: $old_line\nUnknown command $args[0]",
              'bug_id' => $id_bug,
            };
            push(@error_comments, $error);
          }
        }
      }

    }
    my $new_text = join('\n', @lines);

    if ($new_text !~ /^\s*$/){
      my $creation_comment = {
        'thetext' => $new_text,
        'bug_id' => $id_bug,
        'author_' => $comment->author->identity,
      };
      #push(@new_comments, $creation_comment);
    }
    #$comment->remove_from_db();
    #Bugzilla::Comment->create($creation_comment);

  }

  my $map  = {
    create => $create,
    clear => $clear,
    labels => \@labels,
    new_comments => \@new_comments,
    error_comments => \@error_comments,
  };

  return $map;
}

## Remove all error commant.
## Args:
##   $bug_id: id of the bug
sub remove_error{
  my ($bug_id,) = @_;
  my $comments = Bugzilla::Comment->match({bug_id => $bug_id});
  foreach my $comment(@$comments){
    my $text = $comment->body;
    if ($text =~ /^PIVOTAL ERROR: /){
      $comment->remove_from_db();
    }
  }
}

## Create a story on pivotal tracker
## Args:
##    $bug: ref of the bug to link to the story
## Ret:
##    $id_pivotal: int, the id of the story
sub new_pivotal_story{
  my ($bug,) = @_;
  my $id = %$bug{bug_id};

  my $name = $bug->{short_desc};
  my $link_to_bugzilla = "$CONFIG{bugzilla_url}/show_bug.cgi?id=$id\n";
  my $description = 'link to bugzilla: ' . $link_to_bugzilla . get_bug_description($id);
  my $status;
  if (exists($satus_bugzilla_to_pivotal{$bug->{bug_status}})){
    $status = $satus_bugzilla_to_pivotal{$bug->{bug_status}};
  }else{
    $status = $default_pivotal_status;
  }
  my $id_pivotal = create_story($name, $id, $description, $status);
  $bug->{'cf_pivotal_story_id'} = $id_pivotal;
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

  my $story = decode_json($res->{_content});
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
  while ($comment =~ s/ *\/pivotal label *\[(.*?)\]\n?//){} # remove trackerzilla commands
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
