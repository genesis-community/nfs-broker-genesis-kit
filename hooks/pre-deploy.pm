# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::PreDeploy::NFS;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/info bail run/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::PreDeploy);
use JSON::PP;

sub init {
	my ($class, %ops) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	info("\nPerforming pre-deployment validations for NFS Broker...");

	# Check if required static IP is configured
	my $static_ip = $self->env->lookup('params.static_ip');
	if (!$static_ip) {
		bail("No static IP configured for NFS Broker. Please update your environment file.");
	}

	# Verify manifest exists
	if (!-f $ENV{GENESIS_MANIFEST_FILE}) {
		bail("Cannot find manifest file at $ENV{GENESIS_MANIFEST_FILE}");
	}

	info("Pre-deployment validations completed successfully.");

	# Return deployment data
	my $data = {
		'timestamp' => time(),
		'validated' => 1,
	};

	return $self->done(1, JSON::PP::encode_json($data));
}

1;
