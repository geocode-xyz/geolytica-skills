# Geocoder.ca from PHP

```php
<?php
function gca_call(array $params, string $method = 'GET'): array {
    $params = array_merge(['geoit' => 'XML', 'json' => '1'], $params);
    $auth = getenv('GEOCODER_CA_AUTH');
    if ($auth) { $params['auth'] = $auth; }

    for ($attempt = 0; $attempt <= 1; $attempt++) {
        $ch = $method === 'POST'
            ? curl_init('https://geocoder.ca/')
            : curl_init('https://geocoder.ca/?' . http_build_query($params));
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
        ]);
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($params));
        }
        $body = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        curl_close($ch);

        if ($status === 429 && $attempt === 0) { sleep(2); continue; }
        if ($status !== 200) { throw new RuntimeException("HTTP $status"); }

        $data = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
        if (!empty($data['error'])) {
            throw new RuntimeException(
                // Most errors use "description"; 006 (throttled) uses "message".
                "geocoder.ca {$data['error']['code']}: "
                . ($data['error']['description'] ?? $data['error']['message'] ?? '')
            );
        }
        return $data;
    }
    throw new RuntimeException('geocoder.ca 006: throttled; an auth token is needed');
}

function geocode(string $address): ?array {
    $d = gca_call(['locate' => $address, 'standard' => '1', 'showpostal' => '1']);
    if (empty($d['latt'])) { return null; }
    return [
        'lat' => (float) $d['latt'],
        'lon' => (float) $d['longt'],
        'postal' => $d['postal'] ?? null,
        'confidence' => (float) ($d['standard']['confidence'] ?? 0),
        'address' => $d['standard'] ?? [],
        'more' => $d['more'] ?? null,
    ];
}

var_dump(geocode('330 metcalfe ottawa on'));
```

Notes:
- Cast numeric strings with `(float)`.
- Catch the `008` exception and treat it as "no result" in form-validation code.
- Keep the token in the environment or a server-side config file, never in templates.
