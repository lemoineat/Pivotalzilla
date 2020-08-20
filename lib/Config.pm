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


package Bugzilla::Extension::Pivotalzilla::Config;

use 5.10.1;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT = qw(
  %satus_bugzilla_to_pivotal
  %changed_status_on_create
  %create_on_status
  $default_pivotal_status
  $pivotalzibot_compatible
  );

## Map the bugzilla status to the pivotal tracker status
our %satus_bugzilla_to_pivotal = (
  'UNCONFIRMED' => 'unstarted',
  'CONFIRMED' => 'started',
  'IN_PROGRESS' => 'started',
  'RESOLVED' => 'delivered',
  'VERIFIED' => 'accepted',
);

## The status on pivotal if the bugzilla status is not in %satus_bugzilla_to_pivotal
our $default_pivotal_status = 'started';

## When the bug is linked with pivotal create, this hashmap is used to
## change the status to another one automaticaly.
our %changed_status_on_create = (
  'UNCONFIRMED' => 'CONFIRMED'
);

## When a bug change its status for one in this hashmap, a story on pivotal 
## is created and linked to the bug.
our %create_on_status = (
  'CONFIRMED' => 1,
);

## If the extention works with pivotalzibot
our $pivotalzibot_compatible = 0;
1;
