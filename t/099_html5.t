#!/usr/bin/perl
use warnings;
use strict;
use lib ('lib');
use Test::More 'no_plan';
use Petal;

$Petal::BASE_DIR = './t/data/';
$Petal::DISK_CACHE = 0;
$Petal::MEMORY_CACHE = 0;
$Petal::TAINT = 1;
$Petal::OUTPUT = 'XHTML';

my $template = new Petal ('html5.html');
my $string = $template->process;

ok($string);
