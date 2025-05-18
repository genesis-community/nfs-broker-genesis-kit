#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::NFS::RegisterBroker v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use Genesis::UI qw(prompt_for_boolean prompt_for);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

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

	# Get broker information from exodus data
	my $static_ip = $env->lookup('params.static_ip');
	bail("Cannot determine NFS broker IP. Please check your environment configuration.")
		unless $static_ip;

	my $broker_name = $env->exodus_lookup('service_name', 'nfs');
	my $broker_url = $env->exodus_lookup('broker_url', "http://$static_ip");
	my $broker_username = $env->exodus_lookup('broker_username', 'admin');
	my $broker_password = $env->exodus_lookup('broker_password');

	bail("Cannot determine NFS broker password. Please check your exodus data.")
		unless $broker_password;

	# Check if broker already exists
	my $broker_exists = 0;
	($out, $rc) = run({ stderr => 0 }, 'cf service-brokers | grep -q "^$broker_name\\s"');
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
		my $ssl_flag = $skip_ssl_validation ? "--skip-ssl-validation" : "";
		($out, $rc) = run("cf update-service-broker \"$broker_name\" \"$broker_username\" \"$broker_password\" \"$broker_url\" $ssl_flag");
		bail("Failed to update service broker: $out") if $rc != 0;

		info("\n#G{Service broker '$broker_name' successfully updated.}");
	} else {
		if ($broker_exists && $force) {
			info("\nForce option specified. Deleting existing service broker '#C{$broker_name}'...");
			($out, $rc) = run("cf delete-service-broker \"$broker_name\" -f");
			bail("Failed to delete existing service broker: $out") if $rc != 0;
		}

		info("\nRegistering service broker '#C{$broker_name}'...");
		my $ssl_flag = $skip_ssl_validation ? "--skip-ssl-validation" : "";
		($out, $rc) = run("cf create-service-broker \"$broker_name\" \"$broker_username\" \"$broker_password\" \"$broker_url\" $ssl_flag");
		bail("Failed to register service broker: $out") if $rc != 0;

		info("\n#G{Service broker '$broker_name' successfully registered.}");
	}

	# Enable service access
	info("\nEnabling access to services provided by the broker...");
	($out, $rc) = run("cf enable-service-access \"$broker_name\"");
	if ($rc != 0) {
		warning("\nFailed to enable service access. You may need to run 'cf enable-service-access $broker_name' manually.");
	} else {
		info("\n#G{Service access successfully enabled.}");
	}

	return $self->done(1);
}

1;
