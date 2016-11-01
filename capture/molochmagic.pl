#!/usr/bin/perl
# Uses the file magic files to generate molochmagic, which doesn't have all the rules of real lib magic, but will catch many things

use strict;
################################################################################
sub tonum
{
    my ($num) = @_;
    return oct($num) if ($num =~ /^0/);
    return int($num);
}
################################################################################
my $lastfile = "";
sub process {
    my ($mime, @lines) = @_;
    $mime =~ s/!:mime\s+//g;
    $mime =~ s/\s*#.*//g;
    chomp $mime;

    my $cnt = 0;
    if ($lastfile ne $ARGV) {
        $lastfile = $ARGV;
        print "// FILE: $ARGV\n";
    }
    foreach my $line (@lines) {

        $line =~ s/\\ /*SPACE*/g;
        my ($offset, $command, $match, $rest) = $line =~ /([^\s]+)\s+([^\s]+)\s+([^\s]+)\s*(.*)$/;
        $match =~ s/\*SPACE\*/ /g;
        $match =~ s/"/\\"/g;
        $match =~ s/\\</</g;
        $match =~ s/\\>/>/g;
        $match =~ s/\\=/=/g;

        if ($#lines == 0 && $rest ne "") {
            my $op = substr $match, 0, 1;
            if ($op eq "=") {
                $match = substr($match, 1);
            } elsif ($op =~ /<>^/) {
                return;
            }

            if (tonum($offset) > 257) {
                    print "    // LARGE OFFSET: $offset $command $mime\n";
                    return;
            }

            if ($command eq "ustring" || substr($command, 0, 6) eq "string" || $command eq "search/1" || substr($command, 0, 9) eq "search/1/") {
                $match =~ s/\\x(..)/sprintf("\\%03o", hex($1))/eg;
                my $case = index($command, "c", 7) > -1 || index($command, "C", 7) > -1?"TRUE":"FALSE";
                print "    moloch_parsers_molochmagic_add($offset, (uint8_t *)\"$match\", sizeof \"$match\" - 1, \"$mime\", $case);\n";
            } elsif (substr($command, 0, 6) eq "search") {
                my $case = index($command, "c", 7) > -1 || index($command, "C", 7) > -1?"TRUE":"FALSE";
                print "    moloch_parsers_molochmagic_add_search((uint8_t *)\"$match\", sizeof \"$match\" - 1, \"$mime\", $case);\n";
            } elsif ($command eq "beshort") {
                my $val = tonum($match);
                printf("    moloch_parsers_molochmagic_add($offset, (uint8_t *)\"\\x%02x\\x%02x\", 2, \"$mime\", FALSE);\n", ($val >> 8) & 0xff, ($val & 0xff));
            } elsif ($command eq "leshort" || $command eq "short") {
                my $val = tonum($match);
                printf("    moloch_parsers_molochmagic_add($offset, (uint8_t *)\"\\x%02x\\x%02x\", 2, \"$mime\", FALSE);\n", ($val & 0xff), ($val >> 8) & 0xff);
            } elsif ($command eq "ubelong" || $command eq "belong") {
                my $val = tonum($match);
                printf("    moloch_parsers_molochmagic_add($offset, (uint8_t *)\"\\x%02x\\x%02x\\x%02x\\x%02x\", 4, \"$mime\", FALSE);\n", (($val >> 24) & 0xff), (($val >> 16) & 0xff), (($val >> 8) & 0xff), ($val & 0xff));
            } elsif ($command eq "ulelong" || $command eq "lelong" || $command eq "long") {
                my $val = tonum($match);
                printf("    moloch_parsers_molochmagic_add($offset, (uint8_t *)\"\\x%02x\\x%02x\\x%02x\\x%02x\", 4, \"$mime\", FALSE);\n", ($val & 0xff), (($val >> 8) & 0xff), (($val >> 16) & 0xff), (($val >> 24) & 0xff));
            } else {
                    print "    // MISSING COMMAND: $command $match $mime\n";
            }
        } else {
            print "    // MISSING COMPLEX: $mime\n";
            return;
        }

        $cnt ++;
    }

}
################################################################################
print <<EOF;
/* 
 * DO NOT EDIT
 *
 * This file is autogenerated by molochmagic.pl.
 *

 The molochmagic.c file is generated from the libfile (magic/Magdir) magic files
 You can find the latest version at ftp://ftp.astron.com/pub/file

 The COPYING file of the file-5.29 archive contains:

\$File: COPYING,v 1.1 2008/02/05 19:08:11 christos Exp \$
Copyright (c) Ian F. Darwin 1986, 1987, 1989, 1990, 1991, 1992, 1994, 1995.
Software written by Ian F. Darwin and others;
maintained 1994- Christos Zoulas.

This software is not subject to any export provision of the United States
Department of Commerce, and may be exported to any country or planet.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice immediately at the beginning of the file, without modification,
   this list of conditions, and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.
 */
#include "moloch.h"


void molochmagic_load() {
// FILE: molochmagic.pl
    moloch_parsers_molochmagic_add(0, (uint8_t *)"PK\\003\\004", sizeof "PK\\003\\004" - 1, "application/zip", FALSE);
EOF


my @lines = [];
my $level = 0;
while (<>) 
{
    next if (/^#/ || /^$/);
    if (/^!:mime/) {
        process($_, @lines);
        next;
    }
    next if (/^!/);

    if (! /^>/) {
        $level = 0;
    } else {
        $_ =~ m/^(>+)/;
        $level = length ($1);
    }
    $#lines = $level;
    $lines[$level] = $_;
}
print "}\n";

