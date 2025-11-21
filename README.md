# Incident IncidentIO Buildkite Plugin [![Build status](https://badge.buildkite.com/d673030645c7f3e7e397affddd97cfe9f93a40547ed17b6dc5.svg)](https://buildkite.com/buildkite/plugins-template)

Automatically create IncidentIO incidents when Buildkite builds or jobs fail.

## Features

- 🚨 **Automatic incident creation** when builds or jobs fail
- 🎯 **Flexible failure detection** - check build status or job status
- 📝 **Rich incident details** - includes pipeline, branch, build URL, job info, and timestamps
- 🔗 **Buildkite annotations** - creates annotations with direct links to Incident.io incidents
- 🔑 **Secure credential handling** - uses environment variables for integration keys
- ⚙️ **Customizable severity levels** - critical, error, warning, or info

## Required Configuration

### `INCIDENTIO_API_KEY` (string)

The Incident.io API key for your Incident.io account. This is a 68-character hex string (e.g., `inc_0x36x3480x8t0t064t9dt89becex0u8x41x29x8b3c2349295413xe6a3x7fxf91`) that allows you to utilise [Incident.io's API](https://api-docs.incident.io/). 

If you need to create one, follow Incident.io's guide to [create your first incident using API](https://help.incident.io/articles/4081604110-creating-your-first-incident-using-the-api). Use your preferred secret management tool to store the key securely.

```yaml
steps:
  # Fetch secrets once for entire pipeline
  - label: "🔐 Fetch Incident.io Credentials"
    key: "fetch-pagerduty-secrets"
    plugins:
      # Choose your secret management solution:
      - secrets#v1.0.0:                    # Buildkite Secrets
          env:
            INCIDENTIO_API_KEY: incidentio-api-key
      # OR
      - vault-secrets#v2.2.1:              # HashiCorp Vault
          server: ${VAULT_ADDR}
          secrets:
            - path: secret/incidentio/api-key
              field: INCIDENTIO_API_KEY
      # OR  
      - aws-sm#v1.0.0:                     # AWS Secrets Manager
          secrets:
            - name: INCIDENTIO_API_KEY
              key: incidentio/api-key
      # OR
      - aws-ssm#v1.0.0:                    # AWS SSM Parameter Store
          parameters:
            INCIDENTIO_API_KEY: /incidentio/api-key
    command: "./run-tests.sh"
        
```

### `severity-name` (string)

Your Incident.io severity name. Possible severity names in your Incident.io organisation: `SEV-5`, `SEV-1`, etc

## Optional Configuration

### `incident-name` (string)

A brief explanation of the incident. If not provided, a default incident name will be generated.

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
      - incident-incidentio#v1.0.0:
          severity-name: "SEV-1"
          incident-name: "Test Incident"
          incident-summary: "CI tests have failed"
```

## How It Works

1. **Hook Execution**: The plugin runs as a `post-command` hook at the end of your command
2. **Failure Detection**: Checks the current command's exit status to determine if there's a failure
3. **Incident Creation**: If a failure is detected, send a POST request to Incident.io's Create Incidents v2 API
4. **Annotation**: Creates a Buildkite annotation with incident details and a direct link to the Incident.io incident

### Important: Command Requirement

**The plugin requires a `command` in your pipeline step**. This is because the plugin monitors the command's exit status to detect failures.

## Requirements

- Bash
- `curl` (for API calls)
- `jq` (for JSON parsing)
- Incident.io API key
- Buildkite agent with access to make HTTPS requests to `events.pagerduty.com`

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
