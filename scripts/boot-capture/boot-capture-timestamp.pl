#!/usr/bin/perl
# Prefix each serial line on STDIN with the wall-clock time its last byte
# arrived. Partial lines (for example shell prompts) are flushed after
# IDLE_TIMEOUT and keep the time of their last byte, not the timeout fire.
#
# Optional argv[0]: serial device opened write-only. If present, answer the
# ESC[6n cursor-position query so /etc/profile resize() does not add ~2s to
# every captured boot.
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

use constant IDLE_TIMEOUT => 0.1; # seconds
use constant READ_SIZE    => 4096;

$| = 1;

my $reply_fh;
if (@ARGV) {
    open($reply_fh, '>', $ARGV[0]) or undef $reply_fh;
    if ($reply_fh) {
        my $old = select($reply_fh); $| = 1; select($old);
    }
}

my $buf = '';
my $last_read_time;
my $query_pending = 0;

sub emit {
    my ($line, $ts) = @_;
    my ($s, $us) = @$ts;
    # Partial data flushed without '\n' still needs its own line.
    $line .= "\n" unless $line =~ /\n\z/;
    printf "%d.%06d %s", $s, $us, $line;
}

while (1) {
    my $rin = '';
    vec($rin, fileno(STDIN), 1) = 1;
    my $nfound = select($rin, undef, undef, IDLE_TIMEOUT);

    if ($nfound > 0) {
        my $n = sysread(STDIN, my $chunk, READ_SIZE);
        last unless $n;
        $last_read_time = [gettimeofday()];
        $buf .= $chunk;

        if ($reply_fh && !$query_pending && $buf =~ /\033\[6n/) {
            print $reply_fh "\033[24;80R";
            $query_pending = 1;
        }

        while ($buf =~ s/\A(.*?\n)//) {
            emit($1, $last_read_time);
        }
        $query_pending = 0 if $buf eq '';
    } elsif (length($buf)) {
        emit($buf, $last_read_time);
        $buf = '';
        $query_pending = 0;
    }
}

emit($buf, $last_read_time // [gettimeofday()]) if length($buf);
