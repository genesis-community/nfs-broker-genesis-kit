#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::NFS v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/bail info run/;
use Genesis::UI qw(prompt_for_boolean prompt_for);

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->{features} = [];
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Identify network
	my $network = $self->_identify_network();

	# Get static IP
	my $ip = $self->_get_static_ip($network);

	# Create environment file
	$self->_create_environment_file($ip);

	# Offer environment editor
	$self->_offer_environment_editor();

	return $self->done(1);
}

sub _identify_network {
	my ($self) = @_;

	my ($out, $rc) = run({ stderr => 0 }, 'ccq -e \'.networks[] | .name | select(. == "nfs")\' >/dev/null 2>&1');

	if ($rc == 0) {
		return 'nfs';
	}

	($out, $rc) = run('ccq \'.networks | sort_by(.name)| .[] | .name | "-o \\(.)"\'');
	bail("Failed to retrieve networks from cloud config: $out") if $rc != 0;

	my @network_options = split(/\s+/, $out);

	my $network;
	prompt_for('network', 'select',
		'What network do you want to use for this NFS deployment?',
		@network_options, \$network);

	return $network;
}

sub _get_static_ip {
	my ($self, $network) = @_;

	# Get default IP from network
	my ($default_ip, $rc) = run(
		'ccq \'.networks[] | select(.name == $nw) | .subnets[] | select(has("static")) | .static[] \' --arg nw "' . $network . '" | head -n1 | sed -e \'s/\\(^\\|[^0-9]\\)\\(\\(\\([0-9]\\{1,3\\}\\.\\)\\{3\\}[0-9]\\{1,3\\}\\)\\) *$/\\2/\''
	);
	bail("Failed to retrieve static IPs from cloud config: $default_ip") if $rc != 0;

	chomp($default_ip);

	my $default = "";
	if ($default_ip =~ /^([0-9]{1,3}(\.|$)){4}$/) {
		$default = "--default $default_ip";
	}

	my $ip;
	prompt_for('ip', 'line',
		'What static IP do you want to deploy this NFS server on?',
		"--validation ip $default", \$ip);

	return $ip;
}

sub _create_environment_file {
	my ($self, $ip) = @_;

	my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
	open my $fh, ">>", $env_file or bail("Cannot open $env_file for writing: $!");

	print $fh "kit:\n";
	print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
	print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
	print $fh "  features:\n";
	print $fh "    - ((append))\n";

	foreach my $feature (@{$self->{features}}) {
		print $fh "    - $feature\n";
	}

	# Generate and add the genesis_config_block
	my ($out, $rc) = run('genesis_config_block');
	bail("Failed to generate genesis config block: $out") if $rc != 0;

	print $fh $out;

	print $fh "params:\n";
	print $fh "  static_ip: $ip\n";

	close $fh;
}

sub _offer_environment_editor {
	my ($self) = @_;
	my ($out, $rc) = run({ interactive => 1 }, 'offer_environment_editor');
	bail("Failed to offer environment editor: $out") if $rc != 0;
}

1;
