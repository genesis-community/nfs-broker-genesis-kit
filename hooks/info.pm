#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Info::NFS v1.0.0;

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
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Get deployment information
	my $static_ip = $self->env->lookup('params.static_ip');
	bail("Cannot find static IP in environment configuration") unless $static_ip;

	# Get NFS broker credentials from exodus data
	my $broker_username = $self->env->exodus_lookup('broker_username', 'admin');
	my $broker_password = $self->env->exodus_lookup('broker_password', '<not available>');

	info(
		"\n#B{NFS Broker Information}\n".
		"NFS Broker endpoint information\n".
		"\t#C{http://$static_ip}\n".
		"Broker credentials\n".
		"\tusername: #M{$broker_username}\n".
		"\tpassword: #G{$broker_password}\n".
	);

	return $self->done(1);
}

1;
