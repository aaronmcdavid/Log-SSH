#!/usr/bin/perl -w
=head1 Log-SSH

=head2 SYNOPSIS

  Starts a logged SSH session

=head2 DESCRIPTION

  Log-SSH is intended as a wrapper for OpenSSH

=head2 INPUTS

  All switches that SSH normally uses as of v7.2p2

=head2 OUTPUTS

  Executes ssh session and outputs as normal
  Writes log file to ~/logs/<Hostname>.<DateTime>.log

=head2 LINK

 onenote:///\\cs.smrh.net\LAX\NetworkInformation\Network%20Engineering%20Documentation\Scripting.one#ReportingLibrary&section-id={8075F0AF-B197-44DC-8A40-01F51CE8923B}&page-id={5D9E6098-1B28-4BE2-99D5-239A187930C3}&end

=head2 NOTES

  Version:               1.1.0
  Author:                Aaron McDavid
  Author's E-mail:       amcdavid@sheppardmullin.com
  Original Author:       John Simpson <jms1@jms1.net>
  Major Version Date:    2016-04-27
  Current Version Date:  2017-06-29
  Purpose/Change:        Ensure log file is compressed if SigInt is received

=head2 INSTALLATION

  Place this in your ~/bin directory

  Edit the lines below in the configuration section to match your
  environment (by default, set for Cygwin)

  Next, add the following commands to your .bashrc:

    # Automatically log SSH sessions
    alias ssh='Log-SSH.pl'

    # Add user executables to path
    export PATH=$PATH:~/bin

  Then run the following commands:

    mkdir ~/logs
    source .bashrc

=head2 LICENSE

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License, version 3, as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.

=cut

require 5.003 ;
use strict ;
use warnings ;

###############################################################################
#
# Configuration

# the location of your normal "ssh" executable
my $ssh = "/usr/bin/ssh" ;

# the location of your "tee" executable
my $tee = "/usr/bin/tee" ;

# the directory where you want the logs to be stored
# this directory must exist before running the program
my $logdir = "";
my @dirs = ($ENV{"HOME"} . "/logs","//cs.smrh.net/LAX/Users/1acm2/logs",) ;
for my $dir ( @dirs ) {
	if (-d $dir) {
		$logdir = $dir;
		last;
		}
	}

# do you want this script to show the real command before running it?
my $show_cmd = 0 ;

# do you want to compress the log file using bzip2?
our $compress_log_file_bzip2 = 1;

###############################################################################

###############################################################################
#
# Parse arguments, checking for target server and version request

my $target = "" ;
my $request_version_printout = 0;


for my $k ( @ARGV ) {
	if ( $k =~ /^-[1246AaCfGgKkMNnqsTtvXxYy]*V[1246AaCfGgKkMNnqsTtvXxYy]*$/ ) {
		# version printout obviates all other switches
		$request_version_printout = 1 ;
		}
	}

unless ( $request_version_printout ) {
	# target server is the first non-option argument
	my $found_value_option = 0 ;
	for my $k ( @ARGV ) {
		if ( $found_value_option ) {
			# previous ARG was an option; this ARG is its value
			$found_value_option = 0 ;
			next ;
			}
		if ( $k =~ /^-/) {
			# in OpenSSH 7.2p2, these options don't take a value
			if ($k !~ /^-[1246AaCfGgKkMNnqsTtVvXxYy]+$/) {
				$found_value_option = 1 ;
				}
			next ;
			}
		$target = $k ;
		last ;
		}
	}

	if ( $target =~ /\@(.*)$/ ) {
	# if username was specified with @ syntax, use only the hostname
	$target = $1 ;
	}

# re-escape arguments
for (0..$#ARGV) {
	$ARGV[$_] =~ s|([^a-zA-Z0-9,._+@%/\-])|\\$1|g ;
	}

# prepare base cmd
my $cmd = "$ssh " . join ( " " , @ARGV ) ;

# if we can't find a target, neither will ssh
# in this case, don't log anything; just output what ssh outputs
unless ( $target ) {
	exec $cmd ;
}

# construct logfile name
$target = lc $target ;
$target =~ s#([<>:"/\\|?*])#_#g ;		# strip out invalid characters
my @d = localtime ;
my $now = sprintf ( "%04d-%02d-%02d_%02d.%02d.%02d" ,
	$d[5]+1900 , $d[4]+1 , $d[3] , $d[2] , $d[1] , $d[0] ) ;
our $logfile = $logdir . "/${target}.${now}.log" ;


# add logging to our command
$cmd .= " | $tee -a $logfile" ;

# print header to logfile
open ( L , ">$logfile" )
	or die "Can't create logfile \"$logfile\": $!\n" ;
print L "CMD: $cmd\n\n" , "=" x 78 , "\n" ;
close L ;

# execute ssh
$show_cmd && print "% $cmd\n" ;

# begin catching sigint; we want the log file to be compressed even if the process is interrupted
$SIG{INT} = \&compress_log_file;
system $cmd;
&compress_log_file;

#compress log file
sub compress_log_file {
	$SIG{INT} = \&compress_log_file;
	$compress_log_file_bzip2 and system "bzip2 -9 '${logfile}'" ;
}
