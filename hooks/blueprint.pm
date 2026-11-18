#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Blueprint::NFS v1.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->{files} = [];
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($blueprint) = @_; # $blueprint is '$self'

	$blueprint->add_files(qw(
		manifests/nfs.yml
		manifests/releases.yml
	));

	# The kit defines no features of its own. The features hook accepts any
	# feature that has an ops/<feature>.yml file in the environment repo, so
	# merge each of those files after the kit manifests.
	for my $feature ($blueprint->features) {
		my $ops_file = $blueprint->env->path("ops/$feature.yml");
		$blueprint->add_files($ops_file) if -f $ops_file;
	}

	return $blueprint->done();
}

1;
