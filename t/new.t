#!/usr/bin/env perl
# Tests for the NFS broker new hook.  Run with:
#   GENESIS_LIB=<genesis>/lib prove t/
use strict;
use warnings;
use v5.20;
use Test::More;
use File::Basename qw/dirname/;
use File::Spec;

BEGIN { unshift @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib' }

my $hooks = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'hooks'));

# The hook has to compile against the prompt helpers Genesis::UI exports today.
my $loaded = eval { require "$hooks/new.pm"; 1 };
ok($loaded, 'new.pm compiles') or diag($@);
BAIL_OUT('new.pm does not compile') unless $loaded;

my $class = 'Genesis::Hook::New::NFS';
my $self  = bless {}, $class;

no warnings qw(redefine once);
my (@ran, @prompts);

local *Genesis::Hook::New::NFS::prompt_for_choice = sub {
	push @prompts, ['choice', @_];
	my ($prompt, $choices, $default) = @_;
	return $choices->[-1];
};
local *Genesis::Hook::New::NFS::prompt_for_line = sub {
	push @prompts, ['line', @_];
	return '10.99.0.20';
};

# One network named nfs is used without asking
{
	@ran = (); @prompts = ();
	local *Genesis::Hook::New::NFS::run = sub { push @ran, "@_"; return ('nfs', 0) };
	is($self->_identify_network, 'nfs', 'a network named nfs is chosen without a prompt');
	is(scalar(@prompts), 0, 'no prompt was shown');
}

# Otherwise the operator chooses from the cloud config's networks
{
	@ran = (); @prompts = ();
	local *Genesis::Hook::New::NFS::run = sub {
		my @a = @_;
		push @ran, "@a";
		return ('', 1) if "@a" =~ /-e /;
		return ("alpha\nbeta\ngamma", 0);
	};
	is($self->_identify_network, 'gamma', 'the chosen network is returned');
	is($prompts[0][0], 'choice', 'prompt_for_choice is used');
	is_deeply($prompts[0][2], [qw/alpha beta gamma/], 'the choices are the network names, one each');
	like($prompts[0][1], qr/network/, 'the prompt asks about the network');
}

# The static IP is asked for with the first static IP as the default
{
	@ran = (); @prompts = ();
	local *Genesis::Hook::New::NFS::run = sub { return ('10.99.0.16', 0) };
	is($self->_get_static_ip('nfs'), '10.99.0.20', 'the entered IP is returned');
	my ($kind, $prompt, $label, $default, $validation) = @{$prompts[0]};
	is($kind, 'line', 'prompt_for_line is used');
	is($default, '10.99.0.16', 'the first static IP is the default');
	is($validation, 'ip', 'the answer is validated as an IP address');
}

# With no usable static IP there is no default
{
	@ran = (); @prompts = ();
	local *Genesis::Hook::New::NFS::run = sub { return ('', 0) };
	$self->_get_static_ip('nfs');
	ok(!defined($prompts[0][3]), 'no default is offered when the cloud config has no static IP');
}

done_testing;
