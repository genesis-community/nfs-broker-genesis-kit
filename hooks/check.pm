#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Check::NFS v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info/;

sub init {
	my ($class, %ops) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->{ok} = 1; # Start assuming all checks will pass
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Check for static IP
	my $static_ip = $self->env->lookup('params.static_ip');
	if (!$static_ip) {
		info("Missing required parameter 'static_ip' in environment configuration");
		$self->{ok} = 0;
	}

	# Check for valid IP format
	if ($static_ip && $static_ip !~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/) {
		info("Invalid static_ip format: $static_ip. Must be a valid IPv4 address.");
		$self->{ok} = 0;
	}

	# Return the final result
	if ($self->{ok}) {
		$self->env->notify(success => "environment files [#G{OK}]");
	} else {
		$self->env->notify(error => "environment files [#R{FAILED}]");
	}

	return $self->done($self->{ok});
}

1;
