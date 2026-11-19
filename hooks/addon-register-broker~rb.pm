#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::NFS::RegisterBroker v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info warning run/;
use parent qw(Genesis::Hook::Addon);
use Genesis::UI qw(prompt_for_boolean);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

BEGIN {
	require File::Basename;
	require File::Spec;
	require(File::Spec->rel2abs(File::Spec->catfile(File::Basename::dirname(__FILE__), '_broker.pm')));
}

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub cmd_details {
	return
	"Registers the NFS broker with Cloud Foundry.\n".
	"Requires CF CLI to be installed and authenticated with admin privileges.\n".
	"Supports the following options:\n".
	"[[  #y{--skip-ssl-validation} >>Skip SSL validation when connecting to the CF API\n".
	"[[  #y{--force|-f}            >>Force re-registration even if the broker exists\n".
	"[[  #y{--yes|-y}              >>Skip confirmation prompts";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Parse options
	my %options = $self->parse_options([
		'skip-ssl-validation',
		'force|f',
		'yes|y',
	]);

	my $skip_ssl_validation = $options{'skip-ssl-validation'} ? 1 : 0;
	my $force = $options{'force'} ? 1 : 0;
	my $yes = $options{'yes'} ? 1 : 0;

	# Check if CF CLI is installed
	my ($out, $rc) = run({ stderr => 0 }, 'cf version');
	bail("CF CLI is not installed. Please install it and try again.") if $rc != 0;

	# Check if user is logged in to CF
	($out, $rc) = run({ stderr => 0 }, 'cf target');
	if ($rc != 0) {
		bail(
			"You are not logged in to Cloud Foundry.\n".
			"Please log in first with `cf login` or `cf login --sso` and try again."
		);
	}

	# Get the broker details from exodus.  The password
	# goes to the cf CLI in its environment, never on the command line.
	my $details = Genesis::Hook::Addon::NFS::Broker::broker_details($env, $self->vault);
	my $broker_name     = $details->{service_name};
	my $broker_url      = $details->{broker_url};
	my $broker_username = $details->{broker_username};
	my %cf_env          = (CF_BROKER_PASSWORD => $details->{broker_password});
	my @ssl_flag        = $skip_ssl_validation ? ('--skip-ssl-validation') : ();

	# Check if broker already exists
	my $broker_exists = 0;
	($out, $rc) = run({ stderr => 0 }, 'cf service-brokers | grep -q "^$1[[:space:]]"', $broker_name);
	$broker_exists = ($rc == 0);

	if ($broker_exists && !$force) {
		info("\nService broker '#C{$broker_name}' already exists.");
		if (!$yes) {
			my $proceed = prompt_for_boolean(
				"Do you want to update the existing broker configuration?",
				0
			);
			return 0 unless $proceed;
		}

		info("\nUpdating service broker '#C{$broker_name}'...");
		($out, $rc) = run(
			{ env => \%cf_env, redact => 1 },
			'cf', 'update-service-broker', $broker_name, $broker_username, $broker_url, @ssl_flag
		);
		bail("Failed to update service broker: $out") if $rc != 0;

		info("\n#G{Service broker '$broker_name' successfully updated.}");
	} else {
		if ($broker_exists && $force) {
			info("\nForce option specified. Deleting existing service broker '#C{$broker_name}'...");
			($out, $rc) = run('cf', 'delete-service-broker', $broker_name, '-f');
			bail("Failed to delete existing service broker: $out") if $rc != 0;
		}

		info("\nRegistering service broker '#C{$broker_name}'...");
		($out, $rc) = run(
			{ env => \%cf_env, redact => 1 },
			'cf', 'create-service-broker', $broker_name, $broker_username, $broker_url, @ssl_flag
		);
		bail("Failed to register service broker: $out") if $rc != 0;

		info("\n#G{Service broker '$broker_name' successfully registered.}");
	}

	# Enable service access
	info("\nEnabling access to services provided by the broker...");
	($out, $rc) = run('cf', 'enable-service-access', $broker_name);
	if ($rc != 0) {
		warning("\nFailed to enable service access. You may need to run 'cf enable-service-access $broker_name' manually.");
	} else {
		info("\n#G{Service access successfully enabled.}");
	}

	return $self->done(1);
}

1;
