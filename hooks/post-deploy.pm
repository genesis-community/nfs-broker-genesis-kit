#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::NFS v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/info/;
use parent qw(Genesis::Hook::PostDeploy);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
	my ($class, %ops) = @_;
	my $self = $class->SUPER::init(%ops);
	$self->check_minimum_genesis_version('3.1.0-rc.20');
	return $self;
}

sub perform {
	my ($self) = @_;

	# Base class has deploy_successful method to check if GENESIS_DEPLOY_RC == 0
	if ($self->deploy_successful) {
		info(
			"\n#M{$ENV{GENESIS_ENVIRONMENT}} NFS Broker deployed!\n".
			"\nFor details about the deployment, run:\n".
			"\t#G{$ENV{GENESIS_CALL_ENV} info}\n".
			"\nTo open the NFS Broker management endpoint:\n".
			"\t#G{$ENV{GENESIS_CALL_ENV} do -- open}\n".
			"\nTo register the broker with Cloud Foundry:\n".
			"\t#G{$ENV{GENESIS_CALL_ENV} do -- register-broker}\n".
			"\nTo generate a broker-registrar runtime config:\n".
			"\t#G{$ENV{GENESIS_CALL_ENV} do -- runtimeconfig}\n".
		);
	}

	# Call parent class methods if needed
	$self->SUPER::perform() if $self->can('SUPER::perform');

	# Mark the hook as completed successfully
	return $self->done(1);
}

1;

=head1 NAME

Genesis::Hook::PostDeploy::NFS - Post-deployment hook for NFS Broker Genesis Kit

=head1 DESCRIPTION

This module implements the post-deployment hook for the NFS Broker Genesis Kit.
It displays helpful information to the user after a successful deployment.

=head1 METHODS

=head2 init(%options)

Initializes the hook with the given options.

=head2 perform()

Executes the post-deploy hook, displaying helpful information if the deployment was successful.

=head1 AUTHOR

Genesis Framework

=cut
