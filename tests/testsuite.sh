#!/bin/bash
echo "Run Tests..."
bats -t tests/eap-job-tests.bats > eap.tap
bats -t tests/eat-job-tests.bats > eat.tap
bats -t tests/upgrade-components-report-test.bats > upgrade-components-report.tap
cd perun || exit 1
bats -t tests/run-test-unit-tests.bats > ../perun-run-test.tap
bats -t tests/perun-unit-tests.bats > ../perun-unit-tests.tap
cd .. || exit 1
echo 'Done.'
echo ''
echo 'Run Shellcheck on scripts...'
for script_file in *.sh
do
  echo "===== ${script_file} ===="
  shellcheck -e SC2086 -e SC2068 -e SC2181 "${script_file}"
done
echo 'Done.'
