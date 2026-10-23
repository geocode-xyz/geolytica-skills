# Geocoder.ca from Perl

Plain `HTTP::Tiny` and `JSON::PP` (both core since Perl 5.14) are enough. CPAN also has third-party wrappers — `Geo::Coder::CA` (JSON API, Canada and USA) and the older `Geo::Coder::Canada` (XML API) — which are fine for simple lookups but expose fewer parameters than a direct call.

```perl
use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP qw(decode_json);

my $BASE = 'https://geocoder.ca/';
my $AUTH = $ENV{GEOCODER_CA_AUTH};    # undef -> free throttled port
my $http = HTTP::Tiny->new(timeout => 30, agent => 'my-app/1.0');

sub gca_call {
    my (%p) = @_;
    %p = (geoit => 'XML', json => 1, %p);
    $p{auth} = $AUTH if $AUTH;

    for my $attempt (0 .. 1) {
        my $res = $http->post_form($BASE, \%p);
        if ($res->{status} == 429 && $attempt == 0) {
            sleep($res->{headers}{'retry-after'} || 2);
            next;
        }
        die "HTTP $res->{status}\n" unless $res->{success};
        my $d = decode_json($res->{content});
        die "geocoder.ca $d->{error}{code}: $d->{error}{message}\n" if $d->{error};
        return $d;
    }
    die "geocoder.ca 006: throttled; an auth token is needed\n";
}

sub geocode {
    my ($address) = @_;
    my $d = gca_call(locate => $address, standard => 1, showpostal => 1);
    return undef unless length($d->{latt} // '');
    return {
        lat        => 0 + $d->{latt},
        lon        => 0 + $d->{longt},
        postal     => $d->{postal},
        confidence => 0 + ($d->{standard}{confidence} // 0),
        address    => $d->{standard},
        more       => $d->{more},
    };
}

my $r = geocode('330 metcalfe ottawa on');
printf "%.6f,%.6f %s (%.2f)\n", @$r{qw(lat lon postal confidence)} if $r;
```

Notes:
- POST is used here so long `scantext` bodies and unusual characters need no URL escaping.
- `die` on code `008` is usually wrong in batch code; catch it with `eval {}` and log the row as unmatched.
- Without a token, `sleep 1` between calls.
