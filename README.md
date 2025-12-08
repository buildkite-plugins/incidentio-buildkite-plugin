# Incident.io Buildkite Plugin [![Build status](https://badge.buildkite.com/d673030645c7f3e7e397affddd97cfe9f93a40547ed17b6dc5.svg)](https://buildkite.com/buildkite/plugins-template)

Automatically create Incident.io incidents when Buildkite jobs fail.

## Features

- 🚨 **Automatic incident creation** when jobs fail
- 📝 **Customizable incident details** - include custom details to your incident summary
- 🔗 **Buildkite annotations** - creates annotations with direct links to Incident.io incidents
- 🔑 **Secure credential handling** - uses environment variables for api keys
- ⚙️ **Customizable severity levels** - choose whichever severity have been defined in your Incident.io account

## Required Configuration

### `INCIDENTIO_API_KEY` (string)

The Incident.io API key for your organization to utilise [Incident.io's API](https://api-docs.incident.io/). 

If you need to create one, follow Incident.io's guide to [create your first incident using API](https://help.incident.io/articles/4081604110-creating-your-first-incident-using-the-api). Use your preferred [secret management method](https://buildkite.com/docs/pipelines/security/secrets/managing#using-a-secrets-storage-service) to store the key securely.

```yaml
secrets:
  - INCIDENTIO_API_KEY # Retrieve Buildkite Secrets created using Buildkite Interface

steps:
  # OR use Buildkite Secrets plugin to retrieve your key
  - label: "🔐 Fetch Incident.io Credentials"
    key: "fetch-incidentio-secrets"
    plugins:
      - secrets#v1.0.2:
          env:
            INCIDENTIO_API_KEY: incidentio-api-key
    command: "./run-tests.sh"
        
```

### `severity-name` (string)

Your Incident.io severity name. Possible severity names in your Incident.io organisation: `SEV-5`, `SEV-1`, etc

## Optional Configuration

### `incident-name` (string)

A brief explanation of the incident. If not provided, Incident.io will auto generate a random name for your incident.

### `incident-summary` (string)

Detailed description of the incident. If not provided, the incident will be created without a summary.

### `incident-channel-mode` (string)

Whether the incident should be open to anyone in your Slack workspace (`public`), or invite-only (`private`). If not provided, the incident will be created with the default channel mode.

**Options:** `public`, `private`  
**Default:** `public`

### Complete Example

```yaml
steps:
  - label: "🧪 Tests"
    command: "./run-tests.sh"
    plugins:
      - secrets#v1.0.0:
          env:
            INCIDENTIO_API_KEY: incidentio-api-key
      - incidentio#v1.0.0:
          severity-name: "SEV-1"
          incident-name: "Test Incident"
          incident-summary: "CI tests have failed"
```

## How It Works

1. **Hook Execution**: The plugin runs as a `post-command` hook at the end of your command
2. **Failure Detection**: Checks the current command's exit status to determine if there's a failure
3. **Incident Creation**: If a failure is detected, send a POST request to Incident.io's Create Incidents v2 API
4. **Annotation**: Creates a Buildkite annotation with incident details and a direct link to the Incident.io incident

## Requirements

- Bash
- `curl` (for API calls)
- `jq` (for JSON parsing)
- Incident.io API key
- Buildkite agent with access to make HTTPS requests to `api.incident.io`

## Compatibility

| Elastic Stack | Agent Stack K8s | Hosted (Mac) | Hosted (Linux) | Notes |
| :-----------: | :-------------: | :----------: | :------------: | :---- |
|       ✅       |        ✅        |      ✅       |       ✅        | Requires `curl` and `jq` |

- ✅ Fully supported
- ⚠️ Partially supported
- ❌ Not supported

## 👩‍💻 Contributing

1. Follow the patterns established in this template
2. Add tests for new functionality
3. Update documentation for any new options
4. Ensure shellcheck passes (fix issues, don't just disable checks - disabling should be done very seldomly and with team documentation/agreement)
5. Test with the plugin tester

## Developing

**Run all tests:**

```bash
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```

**Validate plugin structure:**

```bash
# Replace 'your-plugin-name' with your actual plugin name
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-linter --id your-plugin-name --path /plugin
```

**Run shellcheck:**

```bash
shellcheck hooks/* tests/* lib/*.bash lib/modules/* lib/providers/*
```

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
