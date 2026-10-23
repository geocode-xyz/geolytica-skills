# Geocode.xyz from Perl

The CPAN module `Geo::Parser::Text` wraps Geocode.xyz geocoding and geoparsing. For full control over parameters and errors, call the API directly with core modules:

```perl
use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP qw(decode_json);

my $BASE = 'https://geocode.xyz/';
my $AUTH = $ENV{GEOCODE_XYZ_AUTH};
my $http = HTTP::Tiny->new(timeout => 60, agent => 'my-app/1.0');

sub clean { my $v = shift; ref $v eq 'HASH' && !%$v ? '' : ($v // '') }

sub gxyz_call {
    my (%p) = @_;
    %p = (json => 1, %p);
    $p{auth} = $AUTH if $AUTH;
    my $res = $http->post_form($BASE, \%p);
    die "HTTP $res->{status}\n" unless $res->{success};
    return decode_json($res->{content});
}

sub geocode {
    my ($loc, $region, $retried) = @_;
    my $d = gxyz_call(locate => $loc, ($region ? (region => $region) : ()));

    if (my $e = $d->{error}) {
        my $s = $d->{suggestion} || {};
        return geocode($s->{locate}, $s->{region} || $region, 1)
            if $e->{code} eq '008' && $s->{locate} && !$retried;
        return undef if $e->{code} eq '008';
        die "geocode.xyz $e->{code}: $e->{description}\n";
    }

    my $std = $d->{standard} || {};
    my $get = sub { my ($k, $alt) = @_; clean($std->{$k}) || clean($d->{$alt // $k}) };
    return undef unless $d->{latt} && $d->{latt} != 0;
    return {
        lat          => 0 + $d->{latt},
        lon          => 0 + $d->{longt},
        street       => $get->('addresst', 'staddress'),
        number       => $get->('stnumber'),
        city         => $get->('city'),
        postal       => $get->('postal'),
        country_code => $get->('prov'),    # country, not province
        confidence   => 0 + ($get->('confidence') || 0),
    };
}

my $r = geocode('Plein 1944 in Nijmegen', 'NL');
printf "%.5f,%.5f %s (%.2f)\n", @$r{qw(lat lon city confidence)} if $r;
```

## Parallel batches with a key

`HTTP::Async` (as in the example on geocode.xyz/api) works well; set `slots` so that total throughput stays at or below 10 requests per second, and write unmatched rows to a separate file rather than dying.
