#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::NFS::RuntimeConfig v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
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
	"Generates a runtime configuration for broker-registrar.\n".
	"This configuration can be used with BOSH to automatically register the NFS broker with Cloud Foundry.\n".
	"Supports the following options:\n".
	"[[  #y{--cf-deployment}       >>Name of the CF deployment to register with (default: <env>-cf)\n".
	"[[  #y{--cf-api-url}          >>URL of the CF API (default: https:// plus the CF exodus api_domain)\n".
	"[[  #y{--output}              >>File to write the runtime config to, readable only by you.\n".
	"[[                            >>It holds the broker password, so without it the password is\n".
	"[[                            >>left out of what is shown\n".
	"[[  #y{--skip-ssl-validation} >>Skip SSL validation when connecting to the CF API";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Parse options
	my %options = $self->parse_options([
		'cf-deployment=s',
		'cf-api-url=s',
		'output=s',
		'skip-ssl-validation',
	]);

	my $cf_deployment = $options{'cf-deployment'} || ($env->name . '-cf');
	my $cf_api_url = $options{'cf-api-url'};
	my $output_file = $options{'output'};
	my $skip_ssl_validation = $options{'skip-ssl-validation'} ? 1 : 0;

	# Get the broker details from exodus.
	my $details = Genesis::Hook::Addon::NFS::Broker::broker_details($env, $self->vault);
	my $broker_name     = $details->{service_name};
	my $broker_url      = $details->{broker_url};
	my $broker_username = $details->{broker_username};
	my $broker_password = $details->{broker_password};

	# The CF kit publishes api_domain, not a URL, so the API URL is built from
	# it.  The CF deployment is named for this environment and the cf kit type.  A CF exodus that
	# predates api_domain still has the system domain in the environment file,
	# and the manifest registers against api.<system_domain>.
	if (!$cf_api_url) {
		my $api_domain = $env->exodus_lookup('api_domain', undef, $env->name . '/cf');
		my $system_domain = $env->lookup('params.system_domain', undef);
		$api_domain = "api.$system_domain"
			if (!defined($api_domain) || $api_domain eq '') && $system_domain;
		bail(
			"Could not determine the CF API URL from the CF exodus data.\n".
			"Please provide it with the --cf-api-url option."
		) unless defined($api_domain) && $api_domain ne '';
		$cf_api_url = "https://$api_domain";
	}

	# Generate runtime config
	info("\nGenerating broker-registrar runtime config for '#C{$broker_name}' service broker.");

	my $skip_ssl_validation_value = $skip_ssl_validation ? "true" : "false";

	my $render = sub {
		my ($password) = @_;
		return <<EOF;
---
releases:
  - name: broker-registrar
    version: 3.5.2
    url: https://bosh.io/d/github.com/cloudfoundry-community/broker-registrar-boshrelease?v=3.5.2
    sha1: 5e49325730c41321b20ac1fe5b9bd93408263f34

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
            password: $password
    include:
      deployments:
        - $cf_deployment
EOF
	};

	# The config holds the broker password, so it only goes to a file that
	# only this user can read.  What is shown on the terminal, which ends up
	# in logs, leaves the password out.
	if ($output_file) {
		my $old_umask = umask(0077);
		my $ok = open(my $fh, '>', $output_file);
		my $err = $!;
		umask($old_umask);
		bail("Cannot write the runtime config to #C{%s}: %s", $output_file, $err) unless $ok;
		print $fh $render->($broker_password);
		close($fh) or bail("Cannot finish writing #C{%s}: %s", $output_file, $!);
		chmod(0600, $output_file);

		info(
			"\nWrote the broker-registrar runtime config to #C{%s}.\n".
			"\nTo apply this runtime config, run:\n".
			"\t#G{bosh -e <bosh-env> update-runtime-config %s}\n".
			"\nThis will configure your BOSH deployment to automatically register the broker with Cloud Foundry.\n",
			$output_file, $output_file
		);
	} else {
		info(
			"\n".
			"\nHere's your broker-registrar runtime config, without the broker password:\n".
			"\t#G{%s}\n".
			"\nTo get a usable file with the password in it, run this addon again with\n".
			"\t#G{--output <file>}\n",
			$render->('<broker password: use --output to write it>')
		);
	}

	return $self->done(1);
}

1;
