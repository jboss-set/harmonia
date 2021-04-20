#!/bin/bash
readonly WORKDIR="${WORKDIR}"

if [ -n "${WORKDIR}" ]; then
  if [ -d "${WORKDIR}" ]; then
    cd "${WORKDIR}" || exit 1
    echo "Run testsuite from provided WORKDIR: $(pwd)"
  else
    echo "Invalid WORKDIR provided: ${WORKDIR}."
  fi
fi

echo "Run Tests..."
bats -t tests/eap-job-tests.bats > eap.tap
bats -t tests/pr-processor-test.bats > pr-processor.tap
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
  shellcheck "${script_file}"
done
echo 'Done.'
