#!/usr/bin/perl
# boot-capture-timestamp.pl — prefix raw serial bytes on STDIN with the
# wall-clock time each line actually arrived, and print to STDOUT.
#
# A complete line is stamped with the time its trailing '\n' was read, even
# if the line was assembled across multiple reads. Data with no trailing
# newline (e.g. an interactive shell prompt) is flushed after IDLE_TIMEOUT
# seconds of silence, stamped with the time its last byte actually arrived
# -- not the time the idle timeout fired -- so the reported time is never
# skewed by how long we waited before giving up on a newline.
#
# Optional argv[0]: the serial device path, opened write-only. /etc/profile's
# resize() sends a cursor-position query (ESC[6n) and blocks for up to 2s
# waiting for a reply -- a real terminal (minicom) answers instantly, but a
# passive reader never does, inflating every captured boot by ~2s for no
# real reason. If given a device, we answer that query ourselves so the
# captured timing matches what an interactive user actually sees.
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
    # idle-flushed partial data (no trailing '\n', e.g. a shell prompt) must
    # still end its own line, or the next emitted timestamp glues onto it
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
