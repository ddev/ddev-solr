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
  # Expected Solr major version, any version by default
  local solr_major_version="${1:-[0-9]+}"

  # Check that the techproducts configset can be uploaded and a corresponding collection will be created
  docker cp ddev-${PROJNAME}-solr:/opt/solr/server/solr/configsets/sample_techproducts_configs .ddev/solr/configsets/techproducts

  run ddev restart -y
  assert_success

  # Give the techproducts collection up to a minute to load
  for _ in {1..20}; do
    curl -sf -o /dev/null "http://${PROJNAME}.ddev.site:8983/solr/techproducts/select?q=*:*" && break
    sleep 3
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
  assert_output --regexp "Location: (http://${PROJNAME}\\.ddev\\.site:8983)?/solr/"

  # Make sure the solr admin UI via HTTPS from outside is redirected to HTTPS /solr/
  run curl -sfI https://${PROJNAME}.ddev.site:8943
  assert_success
  assert_output --partial "HTTP/2 302"
  assert_output --regexp "[Ll]ocation: (https://${PROJNAME}\\.ddev\\.site:8943)?/solr/"

  # Make sure the solr admin UI is working from outside
  run curl -sfL https://${PROJNAME}.ddev.site:8943
  assert_success
  assert_output --partial "Solr Admin"

  # Make sure `ddev solr` command works and runs the expected Solr version
  run ddev solr version
  assert_success
  assert_output --regexp "(^|[^0-9.])${solr_major_version}\.[0-9]+\.[0-9]+"

  # Make sure `ddev solr-zk` command works
  run ddev solr-zk ls /
  assert_success
  assert_output --partial "security.json"

  # Make sure `ddev solr-admin` command works
  DDEV_DEBUG=true run ddev solr-admin
  assert_success
  assert_output --partial "FULLURL https://${PROJNAME}.ddev.site:8943"
}

install_with_base_image() {
  echo "# ddev add-on get ${DIR} with $1 base image in $(pwd)" >&3
  run ddev dotenv set .ddev/.env.solr --solr-base-image "$1"
  assert_success
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
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
  health_checks 10
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
  install_with_base_image "solr:8"
  health_checks 8
}

@test "install from directory Solr 9" {
  set -eu -o pipefail
  install_with_base_image "solr:9"
  health_checks 9
}

@test "install from directory Solr 10" {
  set -eu -o pipefail
  install_with_base_image "solr:10"
  health_checks 10
}
