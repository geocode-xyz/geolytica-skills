---
name: geocoder-ca-autocomplete
description: Add as-you-type Canadian address suggestions to a web form using Geocoder.ca's dependency-free JavaScript autocomplete drop-in. Use when building or fixing a checkout, sign-up, delivery or contact form where users type a Canadian street address, or when replacing a Google Places / Canada Post address-complete field.
---

# Geocoder.ca address autocomplete (front-end)

A single dependency-free JavaScript class that shows real Canadian postal addresses as the user types. Demo and download: https://geocoder.ca/geocoderAutocompleteJs-main/demo.html.

For server-side lookups, validation or anything outside Canada, use the `geocoder-ca-api` or `geocode-xyz-api` skills instead.

## Install

Download the source (minified build plus demo assets) and serve `autocomplete.min.js` from the project's own static files:

```bash
curl -LO https://geocoder.ca/geocoderAutocompleteJs-main/autocomplete.tar.gz
tar -xzf autocomplete.tar.gz
```

```html
<script src="/static/js/autocomplete.min.js"></script>
```

There is no npm package; in a bundled app (React, Vue, etc.) load it as a static script and access the global class after it has loaded.

## Minimal integration

```html
<label for="address">Street address</label>
<div id="address-field">
  <input id="address" name="address" autocomplete="off" />
</div>

<script src="/static/js/autocomplete.min.js"></script>
<script>
  // Don't name the instance `autocomplete` — that would shadow the class.
  const addressAc = new autocomplete({
    input: document.getElementById("address"),
    key: "YOUR_GEOCODER_CA_TOKEN",
    // Keep list-group-item-action: the widget's arrow-key highlighting looks for it.
    itemtemplate:
      '<a href="#" class="list-group-item list-group-item-action ac-item" data-addr="{{geocodeaddr}}">{{geocodeaddr}}</a>'
  });
</script>
```

| Option | Required | Description |
|---|---|---|
| `input` | yes | The input element to attach to. The widget **removes** it and inserts its own input (random id) in the same parent, so wrap it in a container you can query |
| `key` | yes | Geocoder.ca auth token |
| `itemtemplate` | no | HTML for each suggestion; `{{geocodeaddr}}` is replaced with the full address |

The default template in the demo links each suggestion to geocoder.ca. In a form, always supply your own `itemtemplate` so a click doesn't navigate away.

## Capturing the selection

The class (v0.0.1) has no selection callback or event, so handle clicks on your template's items with a delegated listener, put the chosen address in the input, and stop navigation. Look the input up inside your wrapper: `#address` no longer exists once the widget has initialised.

```js
document.addEventListener("click", (e) => {
  const item = e.target.closest(".ac-item");
  if (!item) return;
  e.preventDefault();
  const input = document.querySelector("#address-field input"); // the widget's own input
  input.value = item.dataset.addr;
  input.dispatchEvent(new Event("change", { bubbles: true }));
});
```

Enter does nothing by default (and triggers another lookup). To let keyboard users pick the highlighted item, stop Enter/Escape in the capture phase and select `.ac-item.active` yourself:

```js
const field = document.getElementById("address-field");
field.addEventListener("keyup", (e) => {
  if (e.key === "Enter" || e.key === "Escape") e.stopPropagation();
}, true);
field.addEventListener("keydown", (e) => {
  const active = field.querySelector(".ac-item.active");
  if (e.key === "Enter" && active) { e.preventDefault(); active.click(); }
});
```

## Known widget issues (v0.0.1)

Check these before shipping; the first two need a one-line patch to `autocomplete.js`:

- **Query built from key codes.** `inputValue+=String.fromCharCode(e.keyCode)` sends uppercase letters, adds junk characters for Shift and punctuation, and ignores pasted text. Replace it with `inputValue = document.getElementById(autocompleteinputid).value;`.
- **Query not URL-encoded.** `"&locate="+val` breaks on `&` or `#`. Use `encodeURIComponent(val)`.
- **Absolute image paths.** Icons load from `/geocoderAutocompleteJs-main/img/…`; serve the `img/` folder at exactly that path or the icons are broken.
- **Bootstrap classes.** The generated markup uses `input-group`, `form-control` and `list-group`; style them yourself if the site doesn't use Bootstrap.
- **CORS is open.** Geocoder.ca sends `Access-Control-Allow-Origin: *`, so the widget works from any origin, including `localhost`. The public `test` key is limited to 2 requests per second across all users and is often throttled; use your own widget token.

## Splitting into form fields

`{{geocodeaddr}}` is a single string. If the form needs separate street, city, province and postal-code fields (or coordinates), send the chosen string to your backend and geocode it with the `geocoder-ca-api` skill using `standard=1&showpostal=1`; fill the fields from `standard.stnumber`, `standard.staddress`, `standard.city`, `standard.prov` and `postal`. This also validates the address before you store it.

## Key handling and cost

- The token is visible to anyone who views the page source. Use a token dedicated to this widget, not the one your backend uses, so it can be rotated or capped independently, and watch its usage.
- Autocomplete is a premium function; each lookup uses credits. Don't trigger lookups programmatically (e.g. on page load or when pre-filling the field).
- Never place the token in a public repository; inject it at build or render time from configuration.

## Styling and accessibility

- Style suggestions through your own classes in `itemtemplate`; the demo uses Bootstrap's `list-group-item` classes, which you can drop if the site doesn't use Bootstrap.
- Keep a visible `<label>` on the input and set `autocomplete="off"` so the browser's own autofill list doesn't cover the suggestions.
- Test that a user can still submit an address that isn't suggested (new builds, rural routes); validate it server-side instead of blocking the form.
