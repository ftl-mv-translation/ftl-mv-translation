# Used in CI for nightly packaging

set -x
set -e

mvloc batch-apply $1
mvloc package $1

mv report.txt "packages/batch-apply-report-$1.txt"
cp "output-$1/mod-appendix/metadata.xml" "packages/metadata-$1.xml"

pushd "output-$1"
zip -r "../packages/xml_only-$1.zip" *
popd
