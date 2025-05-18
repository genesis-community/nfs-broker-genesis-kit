#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::NFS v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Based on the original blueprint script comment "validate_features # none"
	# The NFS broker kit doesn't appear to have any specific features to validate

	foreach my $feature (@{$self->{features}}) {
		if ($feature =~ /(ocfp)/) {
			$self->add_feature($feature);
		} elsif (-f $self->env->path("ops/${feature}.yml")) {
			$self->add_feature($feature);
		} else {
			bail(
				"Feature [$feature] not supported in this context.".
				" No specific features are defined for the NFS broker kit."
			);
		}
	}

	return $self->build_features_list();
}

1;
