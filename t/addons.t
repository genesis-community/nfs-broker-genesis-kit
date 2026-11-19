#!/usr/bin/env perl
# Tests for the NFS broker addons.  Run with:
#   GENESIS_LIB=<genesis>/lib prove t/
use strict;
use warnings;
use v5.20;
use Test::More;
use File::Basename qw/dirname/;
use File::Spec;
use File::Temp qw/tempdir/;

BEGIN { unshift @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib' }

my $hooks = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'hooks'));

# A stand-in environment.  It answers from fixed tables, and it dies when
# asked for the broker password in exodus, so a test fails if an addon
# looks there.
package FakeEnv {
	sub new {
		my ($class, %o) = @_;
		return bless {exodus => {}, params => {}, secrets => {}, name => 'base', %o}, $class;
	}
	sub name         { $_[0]{name} }
	sub secrets_base { '/secret/base/nfs/' }
	sub exodus_lookup {
		my ($self, $key, $default, $for) = @_;
		die "the addons must not read the password from exodus\n" if $key =~ /password/;
		$self->{asked_for} = $for if defined $for;
		my $table = defined $for ? ($self->{cf_exodus} // {}) : $self->{exodus};
		return exists $table->{$key} ? $table->{$key} : $default;
	}
	sub lookup {
		my ($self, $key, $default) = @_;
		(my $k = $key) =~ s/^params\.//;
		return exists $self->{params}{$k} ? $self->{params}{$k} : $default;
	}
}

package FakeVault {
	sub new { bless {data => $_[1]}, $_[0] }
	sub get {
		my ($self, $path, $key) = @_;
		push @{$self->{reads}}, "$path:$key";
		return $self->{data}{"$path:$key"};
	}
}

package main;

my $broker = do {
	require "$hooks/_broker.pm";
	'Genesis::Hook::Addon::NFS::Broker'
};

my $vault = FakeVault->new({'/secret/base/nfs/broker:password' => 'pw-from-vault'});

# broker_details with a deployed environment's exodus
{
	my $env = FakeEnv->new(
		exodus => {
			service_name    => 'nfs-svc',
			broker_url      => 'http://nfs-broker.sys.example.com',
			broker_username => 'nfs-broker',
		},
		params => {system_domain => 'ignored.example.com'},
	);
	my $d = $broker->can('broker_details')->($env, $vault);
	is($d->{service_name},    'nfs-svc',                          'service_name comes from exodus');
	is($d->{broker_url},      'http://nfs-broker.sys.example.com', 'broker_url comes from exodus');
	is($d->{broker_username}, 'nfs-broker',                       'broker_username comes from exodus');
	is($d->{broker_password}, 'pw-from-vault',                    'password comes from the secrets store');
	is_deeply($vault->{reads}, ['/secret/base/nfs/broker:password'], 'the secrets store was read at the broker path');
}

# An environment deployed before the exodus keys existed
{
	my $env = FakeEnv->new(params => {system_domain => 'sys.example.com'});
	my $d = $broker->can('broker_details')->($env, $vault);
	is($d->{service_name},    'nfs',                           'service_name defaults to nfs');
	is($d->{broker_url},      'http://nfs-broker.sys.example.com', 'broker_url is built from the system domain');
	is($d->{broker_username}, 'nfs-broker',                    'broker_username defaults to the broker user');
}

# Nothing to derive the URL from
{
	my $env = FakeEnv->new;
	eval { $broker->can('broker_details')->($env, $vault) };
	like($@, qr/broker URL/, 'a missing URL is refused with a message');
}

# No password in the secrets store
{
	my $env = FakeEnv->new(params => {system_domain => 'sys.example.com'});
	eval { $broker->can('broker_details')->($env, FakeVault->new({})) };
	like($@, qr/broker password/, 'a missing password is refused with a message');
	unlike($@, qr/pw-from-vault/, 'the message holds no secret');
}

# register-broker passes the password in the environment, not on the command line
{
	require "$hooks/addon-register-broker~rb.pm";
	my $class = 'Genesis::Hook::Addon::NFS::RegisterBroker';
	my @runs;
	no warnings qw(redefine once);
	local *Genesis::Hook::Addon::NFS::RegisterBroker::run = sub {
		my @a = @_;
		my $opts = ref($a[0]) eq 'HASH' ? shift @a : {};
		push @runs, {opts => $opts, cmd => join(' ', @a), password_env => ($opts->{env} // {})->{CF_BROKER_PASSWORD}};
		# the broker is not registered yet
		return ('', 1) if "@a" =~ /service-brokers/;
		return ('', 0);
	};
	local *Genesis::Hook::Addon::NFS::RegisterBroker::info = sub {};
	my $env = FakeEnv->new(
		exodus => {
			service_name    => 'nfs',
			broker_url      => 'http://nfs-broker.sys.example.com',
			broker_username => 'nfs-broker',
		},
	);
	my $self = bless {env => $env, args => [], vault => FakeVault->new({'/secret/base/nfs/broker:password' => 'pw-from-vault'})}, $class;
	$self->perform;
	my ($create) = grep { $_->{cmd} =~ /create-service-broker/ } @runs;
	ok($create, 'the broker is created');
	unlike(join("\n", map {$_->{cmd}} @runs), qr/pw-from-vault/, 'the password is on no command line');
	is($create->{password_env}, 'pw-from-vault', 'the password goes in CF_BROKER_PASSWORD');
	like($create->{cmd}, qr/nfs-broker/, 'the broker user and URL are passed');
	like($create->{cmd}, qr{http://nfs-broker\.sys\.example\.com}, 'the broker URL is passed');
	my ($exists) = grep { $_->{cmd} =~ /service-brokers/ } @runs;
	like($exists->{cmd}, qr/\bnfs\b/, 'the existence check names the broker');
}

# runtime-config reads the password from the secrets store and keeps it off the terminal
{
	require "$hooks/addon-runtime-config~rc.pm";
	my $class = 'Genesis::Hook::Addon::NFS::RuntimeConfig';
	my @shown;
	no warnings qw(redefine once);
	local *Genesis::Hook::Addon::NFS::RuntimeConfig::info = sub { push @shown, join(' ', @_) };
	my $env = FakeEnv->new(
		exodus => {
			service_name    => 'nfs',
			broker_url      => 'http://nfs-broker.sys.example.com',
			broker_username => 'nfs-broker',
		},
	);
	my $newself = sub {
		return bless {
			env   => $env,
			args  => [@_],
			vault => FakeVault->new({'/secret/base/nfs/broker:password' => 'pw-from-vault'}),
		}, $class;
	};

	$newself->('--cf-api-url', 'https://api.sys.example.com')->perform;
	my $shown = join("\n", @shown);
	unlike($shown, qr/pw-from-vault/, 'the password is not shown on the terminal');
	like($shown, qr{api_url: https://api\.sys\.example\.com}, 'the shown config has the API URL');
	like($shown, qr/--output/, 'the terminal output says how to get the usable file');

	my $dir  = tempdir(CLEANUP => 1);
	my $file = "$dir/broker-registrar.yml";
	@shown = ();
	$newself->('--cf-api-url', 'https://api.sys.example.com', '--output', $file)->perform;
	ok(-f $file, 'the config is written to the output file');
	is(sprintf('%04o', (stat $file)[2] & 07777), '0600', 'the output file is private');
	open my $fh, '<', $file or die $!;
	my $written = do { local $/; <$fh> };
	close $fh;
	like($written, qr/password: pw-from-vault/, 'the file holds the password from the secrets store');
	like($written, qr/username: nfs-broker/, 'the file holds the broker user');
	unlike(join("\n", @shown), qr/pw-from-vault/, 'the password is not shown when writing the file');
}

# runtime-config derives the CF API URL from the CF exodus
{
	require "$hooks/addon-runtime-config~rc.pm";
	my $class = 'Genesis::Hook::Addon::NFS::RuntimeConfig';
	my @shown;
	no warnings qw(redefine once);
	local *Genesis::Hook::Addon::NFS::RuntimeConfig::info = sub { push @shown, join(' ', @_) };
	my %nfs_exodus = (
		service_name    => 'nfs',
		broker_url      => 'http://nfs-broker.sys.example.com',
		broker_username => 'nfs-broker',
	);
	my $run = sub {
		my ($env, @args) = @_;
		@shown = ();
		my $self = bless {
			env   => $env,
			args  => [@args],
			vault => FakeVault->new({'/secret/base/nfs/broker:password' => 'pw-from-vault'}),
		}, $class;
		$self->perform;
		return join("\n", @shown);
	};

	my $env = FakeEnv->new(exodus => \%nfs_exodus, cf_exodus => {api_domain => 'api.cf.example.com'});
	like($run->($env), qr{api_url: https://api\.cf\.example\.com\b}, 'the API URL is https:// plus the CF exodus api_domain');
	is($env->{asked_for}, 'base/cf', 'the CF exodus of the same environment name is read');

	like($run->($env, '--cf-api-url', 'https://api.other.example.com'), qr{api_url: https://api\.other\.example\.com\b},
		'--cf-api-url wins over the exodus');

	# A CF exodus from before api_domain was published, with the system domain in the env file
	my $old = FakeEnv->new(exodus => \%nfs_exodus, cf_exodus => {}, params => {system_domain => 'sys.example.com'});
	like($run->($old), qr{api_url: https://api\.sys\.example\.com\b}, 'the system domain gives the API host when exodus has none');

	my $none = FakeEnv->new(exodus => \%nfs_exodus, cf_exodus => {});
	eval { $run->($none) };
	like($@, qr/--cf-api-url/, 'with nothing to derive it from, the addon asks for --cf-api-url');
}

# runtime-config pins the release the manifest pins and targets the CF deployment
{
	require "$hooks/addon-runtime-config~rc.pm";
	my $class = 'Genesis::Hook::Addon::NFS::RuntimeConfig';
	my @shown;
	no warnings qw(redefine once);
	local *Genesis::Hook::Addon::NFS::RuntimeConfig::info = sub { push @shown, join(' ', @_) };
	my $env = FakeEnv->new(exodus => {
		service_name    => 'nfs',
		broker_url      => 'http://nfs-broker.sys.example.com',
		broker_username => 'nfs-broker',
	});
	my $run = sub {
		@shown = ();
		bless({
			env   => $env,
			args  => [@_],
			vault => FakeVault->new({'/secret/base/nfs/broker:password' => 'pw-from-vault'}),
		}, $class)->perform;
		return join("\n", @shown);
	};

	open my $mf, '<', "$hooks/../manifests/releases.yml" or die $!;
	my $releases = do { local $/; <$mf> };
	close $mf;
	my ($version, $sha1) = $releases =~ /name:\s+broker-registrar\s+version:\s+"([^"]+)"\s+url:[^\n]*\n\s+sha1:\s+(\w+)/;
	ok($version && $sha1, 'the manifest pins broker-registrar');

	my $out = $run->('--cf-api-url', 'https://api.sys.example.com');
	like($out, qr/version: \Q$version\E\b/, 'the runtime config uses the manifest release version');
	like($out, qr/\?v=\Q$version\E\b/, 'the runtime config URL uses the manifest release version');
	like($out, qr/sha1: \Q$sha1\E\b/, 'the runtime config uses the manifest release sha1');
	like($out, qr/include:\s+deployments:\s+- base-cf\b/, 'the runtime config targets the CF deployment, named for the environment and kit type');
	like($out, qr{\(\(base-cf/cf_admin_password\)\)}, 'the admin password is read from the CF deployment');

	$out = $run->('--cf-api-url', 'https://api.sys.example.com', '--cf-deployment', 'other-cf');
	like($out, qr/- other-cf\b/, '--cf-deployment names the targeted deployment');
}

done_testing;
