# Installation

## Claude Code

```
/plugin marketplace add geocode-xyz/geolytica-skills
/plugin install geolytica@geolytica-skills
```

Then restart Claude Code or run `/reload-plugins`.

To make the plugin available to your whole team, add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "geolytica-skills": {
      "source": { "source": "github", "repo": "geocode-xyz/geolytica-skills" }
    }
  }
}
```

Set your keys in the environment the agent runs in:

```bash
export GEOCODER_CA_AUTH=your_geocoder_ca_token
export GEOCODE_XYZ_AUTH=your_geocode_xyz_key
```

## Gemini CLI

```
gemini extensions install https://github.com/geocode-xyz/geolytica-skills
```

## Codex

Add to your project's `AGENTS.md` (or `codex.md`) or agent instructions:

```
Fetch and follow instructions from
https://raw.githubusercontent.com/geocode-xyz/geolytica-skills/refs/heads/main/skills/geocoder-ca-api/SKILL.md
https://raw.githubusercontent.com/geocode-xyz/geolytica-skills/refs/heads/main/skills/geocode-xyz-api/SKILL.md
https://raw.githubusercontent.com/geocode-xyz/geolytica-skills/refs/heads/main/skills/geocoder-ca-autocomplete/SKILL.md
```

## Other agents

The skills are standard markdown files. Point your agent at the relevant file:

- **Geocoder.ca API (Canada/USA):** `skills/geocoder-ca-api/SKILL.md`
- **Geocode.xyz API (worldwide):** `skills/geocode-xyz-api/SKILL.md`
- **Canadian address autocomplete widget:** `skills/geocoder-ca-autocomplete/SKILL.md`

Each `SKILL.md` has a YAML frontmatter `description` field explaining when to use it. The `references/` directory under each API skill contains a full parameter reference and language guides (Python, Node.js, Perl, PHP and command line).

The Geocoder.ca skill is also served live at https://geocoder.ca/SKILL.md, so agents that discover APIs through `https://geocoder.ca/.well-known/api-catalog` find it without installing anything.
