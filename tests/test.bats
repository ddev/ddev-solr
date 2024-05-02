setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/test-solr
  mkdir -p $TESTDIR
  export PROJNAME=test-solr
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  ddev start -y >/dev/null
}

health_checks() {
  ddev logs -s solr
  # Make sure the solr admin UI is working
  ddev exec "curl -sSf -u solr:SolrRocks -s http://solr:8983/solr/# | grep Admin >/dev/null"
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ${DIR}
  ddev restart
  health_checks
  # Check that the techproducts configset was uploaded and a corresponding collection has been created
  ddev exec "curl -sSf -u solr:SolrRocks -s http://solr:8983/solr/techproducts/select?q=*:* | grep numFound >/dev/null"
}

@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get ddev/ddev-solr with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ddev/ddev-solr
  ddev restart >/dev/null
  health_checks
  # Make sure the custom `ddev solr` command works
  ddev solr --help | grep COMMAND >/dev/null
}
