#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::NFS::RuntimeConfig v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub cmd_details {
	return
	"Generates a runtime configuration for broker-registrar.\n".
	"This configuration can be used with BOSH to automatically register the NFS broker with Cloud Foundry.\n".
	"Supports the following options:\n".
	"[[  #y{--cf-deployment}       >>Name of the CF deployment to register with (default: cf)\n".
	"[[  #y{--cf-api-url}          >>URL of the CF API (required if not using exodus data)\n".
	"[[  #y{--skip-ssl-validation} >>Skip SSL validation when connecting to the CF API";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Parse options
	my %options = $self->parse_options([
		'cf-deployment=s',
		'cf-api-url=s',
		'skip-ssl-validation',
	]);

	my $cf_deployment = $options{'cf-deployment'} || 'cf';
	my $cf_api_url = $options{'cf-api-url'};
	my $skip_ssl_validation = $options{'skip-ssl-validation'} ? 1 : 0;

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

	# Try to get CF API URL from exodus data if not provided
	if (!$cf_api_url) {
		# Look up CF API URL from CF exodus data
		my $cf_exodus_base = $env->exodus_base;
		$cf_exodus_base =~ s/nfs/cf/;

		my $cf_api_url_exodus = eval { $env->vault->get($cf_exodus_base.":api_url") };
		if ($cf_api_url_exodus) {
			$cf_api_url = $cf_api_url_exodus;
		} else {
			bail(
				"Could not determine CF API URL from exodus data.\n".
				"Please provide it with the --cf-api-url option."
			);
		}
	}

	# Generate runtime config
	info("\nGenerating broker-registrar runtime config for '#C{$broker_name}' service broker.");

	my $skip_ssl_validation_value = $skip_ssl_validation ? "true" : "false";

	my $runtime_config = <<EOF;
---
releases:
  - name: broker-registrar
    version: 4.1.0
    url: https://bosh.io/d/github.com/cloudfoundry-community/broker-registrar-boshrelease?v=4.1.0
    sha1: e12fa885c4e1a4df19d0b0be8564a1d0e7a34c9f

addons:
  - name: broker-registrar
    jobs:
      - name: broker-registrar
        release: broker-registrar
        properties:
          cf:
            api_url: $cf_api_url
            admin_username: admin
            admin_password: ((${cf_deployment}/cf_admin_password))
            skip_ssl_validation: $skip_ssl_validation_value
          broker:
            name: $broker_name
            url: $broker_url
            username: $broker_username
            password: $broker_password
    include:
      deployments:
        - $env->{name}
EOF

	info(
		"\n".
		"\nHere's your broker-registrar runtime config:\n".
		"\t#G{$runtime_config}\n".
		"\nTo apply this runtime config, save it to a file (e.g., broker-registrar.yml) and run:\n".
		"\t#G{bosh -e <bosh-env> update-runtime-config broker-registrar.yml}\n".
		"\nThis will configure your BOSH deployment to automatically register the broker with Cloud Foundry.\n"
	);

	return $self->done(1);
}

1;
