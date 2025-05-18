#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::NFS::DeregisterBroker v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use Genesis::UI qw(prompt_for_boolean);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub cmd_details {
	return
	"Deregisters the NFS broker from Cloud Foundry.\n".
	"Requires CF CLI to be installed and authenticated with admin privileges.\n".
	"Supports the following options:\n".
	"[[  #y{--recursive|-r}        >>Delete all service instances and bindings first\n".
	"[[  #y{--yes|-y}              >>Skip confirmation prompts";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Parse options
	my %options = $self->parse_options([
		'recursive|r',
		'yes|y',
	]);

	my $recursive = $options{'recursive'} ? 1 : 0;
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

	# Get broker name from exodus data
	my $broker_name = $env->exodus_lookup('service_name', 'nfs');

	# Check if broker exists
	($out, $rc) = run({ stderr => 0 }, 'cf service-brokers | grep -q "^$broker_name\\s"');
	if ($rc != 0) {
		info("\nService broker '#C{$broker_name}' does not exist in Cloud Foundry.");
		return $self->done(1);
	}

	# Confirm deregistration
	if (!$yes) {
		my $proceed = prompt_for_boolean(
			"\nAre you sure you want to deregister the '#C{$broker_name}' service broker from Cloud Foundry?",
			0
		);
		return 0 unless $proceed;
	}

	# Handle recursive deletion of service instances
	if ($recursive) {
		info("\nChecking for service instances that need to be removed...");

		# Get all service offerings from this broker
		my $offerings_cmd = "cf curl \"/v2/service_brokers?q=name:$broker_name\" | jq -r '.resources[0].entity.service_offerings_url'";
		($out, $rc) = run($offerings_cmd);
		bail("Failed to get service offerings URL: $out") if $rc != 0;

		my $offerings_url = $out;
		chomp($offerings_url);

		if ($offerings_url) {
			# Get the service plans
			my $plans_cmd = "cf curl \"$offerings_url\" | jq -r '.resources[].entity.service_plans_url'";
			($out, $rc) = run($plans_cmd);
			bail("Failed to get service plans: $out") if $rc != 0;

			my @plan_urls = split(/\n/, $out);

			# Process each plan
			foreach my $plan_url (@plan_urls) {
				# Get instances for this plan
				my $instances_cmd = "cf curl \"$plan_url/service_instances\" | jq -r '.resources[].entity.name'";
				($out, $rc) = run($instances_cmd);
				bail("Failed to get service instances: $out") if $rc != 0;

				my @instances = split(/\n/, $out);
				foreach my $instance (@instances) {
					next unless $instance;
					info("  Deleting service instance '#C{$instance}'...");
					($out, $rc) = run("cf delete-service \"$instance\" -f");
					warning("    Failed to delete service instance: $out") if $rc != 0;
				}
			}
		}

		# Wait for service instances to be deleted
		info("\nWaiting for all service instances to be deleted...");
		sleep 5;  # Give CF some time to process
	}

	# Deregister the broker
	info("\nDeregistering service broker '#C{$broker_name}'...");
	($out, $rc) = run("cf delete-service-broker \"$broker_name\" -f");
	bail("Failed to deregister service broker: $out") if $rc != 0;

	info("\n#G{Service broker '$broker_name' successfully deregistered from Cloud Foundry.}");

	return $self->done(1);
}

1;
