#!/usr/bin/perl
# Quick hack to get dns lists into IPs so I don't spew so much DNS traffic out while working on code
# leon@rn-rf.co.uk

use strict;
use warnings;
use Socket;


my $line=1;
while (<STDIN>) {
    my $name = $_;
    chomp $name;
    if (gethostbyname($name)) {
        my $ip = inet_ntoa(inet_aton($name));
        print "$ip,192.168.0.1,\"$name\", \"$name\"\n";
    } else {
            print "# Error on line $line $name\n";
    }
    $line++;
}

