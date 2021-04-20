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

runTests() {
  for tests in tests/*.bats
  do
    local tests_file=$(basename "${1}")
    bats -t "${tests}" > "${tests_file%.bats}.tap"
  done
}

echo -n 'Run Tests...'
runTests
cd perun || exit 1
runTests
cd .. || exit 1
echo 'Done.'
echo ''
echo -n 'Run Shellcheck on scripts...'
shellcheck_report='shellcheck.html'
echo '<html><title>Shellcheck report</title><body>' > "${shellcheck_report}"
for script_file in *.sh perun/*.sh
do
  echo "<h1>${script_file}</h1>" >> "${shellcheck_report}"
  shellcheck --format=quiet "${script_file}"
  if [ "${?}" -ne 0 ] ; then
      echo "Violations found" >> "${shellcheck_report}"
  fi
done
echo '</body></html>' >> "${shellcheck_report}"
echo 'Done.'
