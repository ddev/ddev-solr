#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=ddev/ddev-solr

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Check that the techproducts configset can be uploaded and a corresponding collection will be created
  docker cp ddev-${PROJNAME}-solr:/opt/solr/server/solr/configsets/sample_techproducts_configs .ddev/solr/configsets/techproducts

  run ddev restart -y
  assert_success

  # Wait for Solr to be ready
  while true; do
    # Try to reach the Solr admin ping URL
    if curl --output /dev/null --silent --head --fail http://${PROJNAME}.ddev.site:8983/solr/techproducts/select?q=*:*; then
      break
    else
      echo "Waiting three more seconds for Solr to be ready..." >&3
      sleep 3 # Wait for 3 seconds before retrying
    fi
  done

  # Check authenticated read access
  run ddev exec "curl -sf -u solr:SolrRocks http://solr:8983/solr/techproducts/select?q=*:*"
  assert_success
  assert_output --partial "numFound"

  # Check unauthenticated read access
  run ddev exec "curl -sf http://solr:8983/solr/techproducts/select?q=*:*"
  assert_success
  assert_output --partial "numFound"

  # Make sure the solr admin UI is working
  run ddev exec "curl -sf -u solr:SolrRocks http://solr:8983/solr/#"
  assert_success
  assert_output --partial "Solr Admin"

  # Make sure the solr admin UI via HTTP from outside is redirected to HTTP /solr/
  run curl -sfI http://${PROJNAME}.ddev.site:8983
  assert_success
  assert_output --partial "HTTP/1.1 302"
  assert_output --partial "Location: http://${PROJNAME}.ddev.site:8983/solr/"

  # Make sure the solr admin UI via HTTPS from outside is redirected to HTTPS /solr/
  run curl -sfI https://${PROJNAME}.ddev.site:8943
  assert_success
  assert_output --partial "HTTP/2 302"
  assert_output --partial "location: https://${PROJNAME}.ddev.site:8943/solr/"

  # Make sure the solr admin UI is working from outside
  run curl -sfL https://${PROJNAME}.ddev.site:8943
  assert_success
  assert_output --partial "Solr Admin"

  # Make sure the custom `ddev solr` command works
  run ddev solr
  assert_success
  assert_output --partial "COMMAND"

  # Make sure the custom `ddev solr-zk` command works
  run ddev solr-zk ls /
  assert_success
  assert_output --partial "security.json"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "install from directory Solr 8" {
  set -eu -o pipefail

  echo "⚡ Setting Solr base image to Solr 8.x.x" >&3
  run ddev dotenv set .ddev/.env.solr --solr-base-image "solr:8"
  assert_success
  assert_file_exist .ddev/.env.solr

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  echo "🔍 Retrieving Solr version..." >&3
  echo $(ddev solr version) >&3
  SOLR_VERSION=$(ddev solr version | grep -oE '8\.[0-9]+\.[0-9]+' || { printf "❌ Failed to get Solr version\n" >&2; exit 1; })

  echo "🔍 Retrieved Solr version: '$SOLR_VERSION'" >&3

  # Validate that the version starts with 8.x.x
  if ! [[ $SOLR_VERSION =~ ^8\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Expected version matching '8.x.x' but got '$SOLR_VERSION'" >&2
    exit 1
  fi

  echo "✅ Solr 8.x.x version check passed!" >&3
}
