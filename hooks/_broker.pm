# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::NFS::Broker v1.0.0;

# Shared lookups for the NFS broker addons.  This is a helper, not a hook,
# so the addons load it with require.

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

use Genesis qw/bail/;

# broker_details - what the addons need to register or describe the broker {{{
# Takes the environment and the secrets store, and returns a hash reference
# with service_name, broker_url, broker_username, and broker_password.
#
# The name, URL, and user come from the exodus data this kit publishes.  An
# environment deployed before the kit published them has none, so each one
# falls back to the value the manifest uses.  The password is never in exodus.
# It is read from the secrets store, where the kit generated it.
sub broker_details {
	my ($env, $vault) = @_;

	my $system_domain = $env->lookup('params.system_domain', undef);
	my $broker_url = $env->exodus_lookup('broker_url', undef);
	$broker_url = "http://nfs-broker.$system_domain"
		if (!defined($broker_url) || $broker_url eq '') && $system_domain;
	bail(
		"Cannot determine the NFS broker URL.  It is missing from the exodus data, ".
		"and #C{params.system_domain} is not set in the environment file."
	) unless defined($broker_url) && $broker_url ne '';

	my $path = $env->secrets_base . 'broker';
	my $broker_password = $vault->get($path, 'password');
	bail(
		"Cannot read the NFS broker password from the secrets store at #C{%s:password}.  ".
		"Check that the environment's secrets have been added.", $path
	) unless defined($broker_password) && $broker_password ne '';

	return {
		service_name    => $env->exodus_lookup('service_name',    'nfs'),
		broker_url      => $broker_url,
		broker_username => $env->exodus_lookup('broker_username', 'nfs-broker'),
		broker_password => $broker_password,
	};
}

# }}}

1;
