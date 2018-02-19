#!/usr/bin/perl

use Getopt::Long;

my ($opt_c, $opt_w, $opt_i, $opt_r, $opt_h);

sub print_usage () {
  print "
Nagios script for checking CPU load.

  usage: $0 [-w value] [-c value] [-i value] [-r value]
         $0 -h
         
  --warning, -w   Warning threshold, percen, default is 75
  --critical, -c  Critical threshold, percent, default is 90
  --reports, -r   The number of reports used for aggregation, default is 2
  --interval, -i  The interval between repors, default is 1
  --help, -h      This.
  "
};

GetOptions
  ("h"  =>  \$opt_h, "help" => \$opt_h,
   "w=f" => \$opt_w, "warning=f"  => \$opt_w, 
   "c=f" => \$opt_c, "critical=f" => \$opt_c,
   "r=i" => \$opt_r, "reports=i" => \$opt_r,
   "i=i" => \$opt_i, "interval=i" => \$opt_i,
  ) or exit 0;

# default values
unless (defined $opt_w) {
  $opt_w = 75;
}

unless ( defined $opt_c ) {
  $opt_c = 90;
}

unless ( defined $opt_r) {
  $opt_r = 2;
}

unless ( defined $opt_i) {
  $opt_i = 1;
}

if ($opt_h) {print_usage(); exit 0;}

if ($opt_c < $opt_w) {
  print "Error: Warning (-w) cannot be greater than Critical (-c)\n";
  exit 0;
}

@mpstat = `mpstat $opt_i $opt_r | tail -1`;
for $line (@mpstat) {
  chomp($line);
  $line =~ s/\s+/,/g;
  ($time, $cpu, $usr, $nice, $sys, $iowait, $irq, $soft, $steal, $guest, $idle) = split(/,/,"$line");
  $usage = $usr + $sys;
  if($usage >= $opt_w) {
   $exit = 1;
  }
  elsif($usage >= $opt_c) {
   $exit = 2; 
  }
  else {
  $exit = 0
  }
}
if($exit == 0) {
  print "CPU OK: $usage%\n";
  exit 0;
}
elsif($exit == 1) {
  print "CPU WARNING: $usage%\n";
  exit 1;
}
elsif($exit == 2) {
  print "CPU CRITICAL: $usage%\n";
  exit 2;
}

