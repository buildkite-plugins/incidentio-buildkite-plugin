#!/usr/bin/env bats

# shellcheck disable=SC2030,SC2031

load "${BATS_PLUGIN_PATH}/load.bash"

setup() {
  export BUILDKITE_PIPELINE_SLUG="test-pipeline"
  export BUILDKITE_BUILD_NUMBER="123"
  export BUILDKITE_LABEL="Test Job"
  export BUILDKITE_BUILD_ID="test-build-id"
  export BUILDKITE_JOB_ID="test-job-id"
  export INCIDENTIO_API_KEY="test-key"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"

  # Create a temporary directory for our mocks
  MOCK_DIR="$(mktemp -d)"
  export MOCK_DIR
  export PATH="${MOCK_DIR}:$PATH"

  # Mock buildkite-agent (default: echo stdin to stdout)
  cat << 'EOF' > "${MOCK_DIR}/buildkite-agent"
#!/bin/bash
cat
EOF
  chmod +x "${MOCK_DIR}/buildkite-agent"

  # Mock curl (default: success response)
  cat << 'EOF' > "${MOCK_DIR}/curl"
#!/bin/bash
case "$*" in
  *"/v1/severities"*)
    echo '{"severities":[{"id":"sev-123","name":"SEV-5"}]}'
    ;;
  *"/v2/incidents"*)
    printf '{"incident":{"id":"inc-123","name":"Test","permalink":"https://example.com/inc/123","severity":{"name":"SEV-5"}}}\n200'
    ;;
  *)
    echo "{}"
    ;;
esac
EOF
  chmod +x "${MOCK_DIR}/curl"
}

teardown() {
  rm -rf "$MOCK_DIR"
}

@test "Skips incident creation on successful job (exit 0)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=0
  export BUILDKITE_PLUGIN_DEBUG=true

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Job completed successfully - no incident"
}

@test "Skips incident creation on graceful termination (exit 143)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=143
  export BUILDKITE_PLUGIN_DEBUG=true

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Job gracefully terminated (exit 143) - no incident"
}

@test "Skips incident creation on agent termination (exit 255)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=255
  export BUILDKITE_PLUGIN_DEBUG=true

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Job gracefully terminated (exit 255) - no incident"
}

@test "Creates incident log on job failure (exit 1)" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  run "$PWD/hooks/post-command"

  assert_output --partial "Incident created"
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
  export BUILDKITE_PLUGIN_DEBUG=false
  unset BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "SEVERITY_NAME is required but not provided"
}

@test "Fails when severity name not found" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-INVALID"

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "Severity 'SEV-INVALID' not found"
}

@test "Matches severity name case-insensitively" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="sev-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"
  export BUILDKITE_PLUGIN_DEBUG=true

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Using severity ID: sev-123"
}

@test "Uses default public visibility when not specified" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: Test"
}

@test "Uses custom incident name and summary" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Custom Incident Name"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_SUMMARY="Custom summary description"

  # Override curl mock for this specific test to return custom name
  cat << 'EOF' > "${MOCK_DIR}/curl"
#!/bin/bash
case "$*" in
  *"/v1/severities"*)
    echo '{"severities":[{"id":"sev-123","name":"SEV-5"}]}'
    ;;
  *"/v2/incidents"*)
    printf '{"incident":{"id":"inc-123","name":"Custom Incident Name","permalink":"https://example.com/inc/123","severity":{"name":"SEV-5"}}}\n200'
    ;;
  *)
    echo "{}"
    ;;
esac
EOF
  chmod +x "${MOCK_DIR}/curl"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: Custom Incident Name"
}

@test "Uses private visibility when specified" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_CHANNEL_MODE="private"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Incident created: Test"
}

@test "Fails when incident creation returns non-2xx status" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Test"

  # Override curl mock to return failure
  cat << 'EOF' > "${MOCK_DIR}/curl"
#!/bin/bash
case "$*" in
  *"/v1/severities"*)
    echo '{"severities":[{"id":"sev-123","name":"SEV-5"}]}'
    ;;
  *"/v2/incidents"*)
    printf '{"error":"Invalid request"}\n422'
    ;;
  *)
    echo "{}"
    ;;
esac
EOF
  chmod +x "${MOCK_DIR}/curl"

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial "Failed to create incident (HTTP 422)"
}

@test "Creates annotation with incident details" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_SEVERITY_NAME="SEV-5"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_NAME="Build Failure"
  export BUILDKITE_PLUGIN_INCIDENT_INCIDENTIO_INCIDENT_SUMMARY="Tests failed"

  # Override curl mock to return specific details matching assertions
  cat << 'EOF' > "${MOCK_DIR}/curl"
#!/bin/bash
case "$*" in
  *"/v1/severities"*)
    echo '{"severities":[{"id":"sev-123","name":"SEV-5"}]}'
    ;;
  *"/v2/incidents"*)
    printf '{"incident":{"id":"inc-456","name":"Build Failure","permalink":"https://example.incident.io/incidents/456","severity":{"name":"SEV-5"}}}\n200'
    ;;
  *)
    echo "{}"
    ;;
esac
EOF
  chmod +x "${MOCK_DIR}/curl"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "🚨 Incident Created"
  assert_output --partial "[Build Failure](https://example.incident.io/incidents/456)"
  assert_output --partial "SEV-5"
  assert_output --partial "Pipeline: test-pipeline"
  assert_output --partial "Build: #123"
  assert_output --partial "Exit Status: 1"
}
