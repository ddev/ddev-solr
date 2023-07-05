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
  # Make sure the solr admin UI is working
  ddev exec "curl -sSf -u solr:SolrRocks -s http://solr:8983/solr/# | grep Admin >/dev/null"
  # Make sure the custom `ddev solr` command works
  ddev solr --help | grep COMMAND >/dev/null
  #echo "# curl -v -sSf -u solr:SolrRocks -X POST --header \"Content-Type:application/octet-stream\" --data-binary \"@${DIR}/tests/testdata/techproducts_configset.zip\" \"http://${PROJNAME}.ddev.site:8983/solr/admin/configs?action=UPLOAD&name=techproducts_configset\"" >&3
  # Upload the techproducts configset
  # Use `curl -v` to learn more about what's going wrong
  curl -sSf -u solr:SolrRocks -X POST --header "Content-Type:application/octet-stream" --data-binary "@${DIR}/tests/testdata/techproducts_configset.zip" "http://${PROJNAME}.ddev.site:8983/solr/admin/configs?action=UPLOAD&name=techproducts_configset"
  # Check to make sure the configset was uploaded and can be used
  curl -v -sSf -u solr:SolrRocks "http://${PROJNAME}.ddev.site:8983/solr/admin/collections?action=CREATE&name=newCollection&numShards=1&replicationFactor=1&collection.configName=techproducts_configset"
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
}

@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get mkalkbrenner/ddev-solr with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get mkalkbrenner/ddev-solr
  ddev restart >/dev/null
  health_checks
}
