# Geocode.xyz from PHP

```php
<?php
function gxyz_call(array $params): array {
    $params = array_merge(['json' => '1'], $params);
    $auth = getenv('GEOCODE_XYZ_AUTH');
    if ($auth) { $params['auth'] = $auth; }

    $ch = curl_init('https://geocode.xyz/');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS => http_build_query($params),
        CURLOPT_TIMEOUT => 60,
    ]);
    $body = curl_exec($ch);
    $status = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    if ($status !== 200) { throw new RuntimeException("HTTP $status"); }
    return json_decode($body, true, 512, JSON_THROW_ON_ERROR);
}

function clean($v) { return (is_array($v) && !$v) ? '' : ($v ?? ''); }

function geocode(string $loc, ?string $region = null, bool $retried = false): ?array {
    $d = gxyz_call(array_filter(['locate' => $loc, 'region' => $region]));

    if (!empty($d['error'])) {
        $s = $d['suggestion'] ?? [];
        if ($d['error']['code'] === '008' && is_string($s['locate'] ?? null) && $s['locate'] !== '' && !$retried) {
            return geocode($s['locate'], $s['region'] ?? $region, true);
        }
        if ($d['error']['code'] === '008') { return null; }
        throw new RuntimeException("geocode.xyz {$d['error']['code']}: {$d['error']['description']}");
    }

    $std = $d['standard'] ?? [];
    $get = fn($k, $alt = null) => clean($std[$k] ?? null) ?: clean($d[$alt ?? $k] ?? null);
    if ((float) ($d['latt'] ?? 0) == 0.0) { return null; }
    // confidence 0 means no match, even with coordinates
    if ((float) ($get('confidence') ?: 0) == 0.0) { return null; }
    return [
        'lat' => (float) $d['latt'],
        'lon' => (float) $d['longt'],
        'street' => $get('addresst', 'staddress'),
        'city' => $get('city'),
        'postal' => $get('postal'),
        'country_code' => $get('prov'), // country, not province
        'confidence' => (float) ($get('confidence') ?: 0),
    ];
}

function geoparse(string $text, ?string $region = null): array {
    return gxyz_call(array_filter(['scantext' => $text, 'region' => $region]));
}

var_dump(geocode('Stora Torget 1, 582 19 Linkoping', 'SE'));
```
