# Used in CI for nightly packaging

set -x
set -e

mvloc batch-apply $1
mv report.txt "packages/batch-apply-report-$1.txt"

mvloc package $1

pushd "output-$1"
zip -r "../packages/xml_only-$1.zip" *
popd
