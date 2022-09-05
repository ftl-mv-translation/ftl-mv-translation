# Used in CI for nightly packaging

set -x
set -e

mvloc batch-apply $1
mvloc package $1

mv report.txt "packages/batch-apply-report-$1.txt"

pushd "output-$1"
zip -r "../packages/xml_only-$1.zip" *
popd
