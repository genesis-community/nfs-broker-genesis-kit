#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::CloudConfig::NFS v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	my $config = $self->build_cloud_config({
		'networks' => [
			$self->network_definition('nfs', strategy => 'ocfp',
				dynamic_subnets => {
					allocation => {
						size => 0,
						statics => 0,
					},
					cloud_properties_for_iaas => {
						openstack => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => ['default']
						},
						aws => {
							'subnet' => $self->network_reference('id')
						},
					},
				},
			)
		],
		'vm_types' => [
			$self->vm_type_definition('nfs',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'm1.small',
							prod => 'm1.medium'
						}, 'm1.small'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 20 # in gigabytes
						},
					},
					aws => {
						'instance_type' => $self->for_scale({
							dev => 't3.medium',
							prod => 'm6i.large'
						}, 't3.medium'),
						'ephemeral_disk' => {
							'size' => $self->for_scale({
								dev => 16384,
								prod => 16384
							}, 16384),
							'type' => 'gp3',
							'encrypted' => $self->TRUE
						},
						'metadata_options' => {
							'http_tokens' => 'required'
						}
					},
				},
			),
		],
		'disk_types' => [
			$self->disk_type_definition('nfs',
				common => {
					disk_size => $self->for_scale({
						dev => 32768,
						prod => 65536
					}, 32768),
				},
				cloud_properties_for_iaas => {
					openstack => {
						'type' => 'storage_premium_perf6',
					},
					aws => {
						'type' => 'gp3',
						'encrypted' => $self->TRUE
					},
				},
			),
		],
	});

	$self->done($config);
}

1;