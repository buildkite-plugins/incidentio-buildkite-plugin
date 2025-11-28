#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

setup() {
  export BUILDKITE_COMMAND_EXIT_STATUS=0
  export BUILDKITE_PIPELINE_SLUG="test-pipeline"
  export BUILDKITE_BUILD_NUMBER="123"
  export BUILDKITE_LABEL="Test Job"
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
}

@test "Skips incident creation on successful job (exit 0)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=0

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Job completed successfully - no incident"
}

@test "Skips incident creation on graceful termination (exit 143)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=143

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Job gracefully terminated (exit 143) - no incident"
}

@test "Skips incident creation on agent termination (exit 255)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=255

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Job gracefully terminated (exit 255) - no incident"
}

@test "Creates incident on job failure (exit 1)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"incident\":{\"id\":\"inc-123\",\"name\":\"Test\",\"permalink\":\"https://example.com/inc/123\",\"severity\":{\"name\":\"SEV-5\"}}}\n200"'

  stub buildkite-agent \
    'annotate --style error : cat'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: inc-123"
  unstub curl
  unstub buildkite-agent
}

@test "Fails when API key is missing" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  unset INCIDENTIO_API_KEY

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "INCIDENTIO_API_KEY is required but not provided"
}

@test "Fails when severity name is missing" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  unset BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "SEVERITY_NAME is required but not provided"
}

@test "Fails when severity name not found" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-INVALID"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"'

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "Severity 'SEV-INVALID' not found"
  unstub curl
}

@test "Matches severity name case-insensitively" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="sev-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"incident\":{\"id\":\"inc-123\",\"name\":\"Test\",\"permalink\":\"https://example.com/inc/123\",\"severity\":{\"name\":\"SEV-5\"}}}\n200"'

  stub buildkite-agent \
    'annotate --style error : cat'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Using severity ID: sev-123"
  unstub curl
  unstub buildkite-agent
}

@test "Uses default public visibility when not specified" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"incident\":{\"id\":\"inc-123\",\"name\":\"Test\",\"permalink\":\"https://example.com/inc/123\",\"severity\":{\"name\":\"SEV-5\"}}}\n200"'

  stub buildkite-agent \
    'annotate --style error : cat'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: inc-123"
  
  unstub curl
  unstub buildkite-agent
}

@test "Uses custom incident name and summary" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Custom Incident Name"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_SUMMARY="Custom summary description"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"incident\":{\"id\":\"inc-123\",\"name\":\"Custom Incident Name\",\"permalink\":\"https://example.com/inc/123\",\"severity\":{\"name\":\"SEV-5\"}}}\n200"'

  stub buildkite-agent \
    'annotate --style error : cat'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: inc-123"
  
  unstub curl
  unstub buildkite-agent
}

@test "Uses private visibility when specified" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_CHANNEL_MODE="private"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"incident\":{\"id\":\"inc-123\",\"name\":\"Test\",\"permalink\":\"https://example.com/inc/123\",\"severity\":{\"name\":\"SEV-5\"}}}\n200"'

  stub buildkite-agent \
    'annotate --style error : cat'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: inc-123"
  
  unstub curl
  unstub buildkite-agent
}

@test "Fails when incident creation returns non-2xx status" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"error\":\"Invalid request\"}\n422"'

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "Failed to create incident (HTTP 422)"
  
  unstub curl
}

@test "Creates annotation with incident details" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Build Failure"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_SUMMARY="Tests failed"
  export BUILDKITE_PIPELINE_SLUG="test-pipeline"
  export BUILDKITE_BUILD_NUMBER="123"
  export BUILDKITE_LABEL="Test Job"

  stub curl \
    '-s -X GET https://api.incident.io/v2/severities -H "Authorization: Bearer test-key" : echo "{\"severities\":[{\"id\":\"sev-123\",\"name\":\"SEV-5\"}]}"' \
    '-s -w "\n%{http_code}" -X POST https://api.incident.io/v2/incidents -H "Content-Type: application/json" -H "Authorization: Bearer test-key" -d * : printf "{\"incident\":{\"id\":\"inc-456\",\"name\":\"Build Failure\",\"permalink\":\"https://example.incident.io/incidents/456\",\"severity\":{\"name\":\"SEV-5\"}}}\n200"'

  stub buildkite-agent \
    'annotate --style error : cat'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "🚨 Incident Created"
  assert_output --partial "[Build Failure](https://example.incident.io/incidents/456)"
  assert_output --partial "inc-456"
  assert_output --partial "SEV-5"
  assert_output --partial "Pipeline: test-pipeline"
  assert_output --partial "Build: #123"
  assert_output --partial "Exit Status: 1"
  
  unstub curl
  unstub buildkite-agent
}
