#!/usr/bin/env bash

test_start()        { echo -e "[.] $*"; }
test_passed()       { echo -e "[+] $*"; }
test_failed()       { echo -e "[-] $*"; }

readonly SCRIPT_PATH="$( dirname $(realpath ${0}) )"
readonly STATICS_PATH="${SCRIPT_PATH}/static"
readonly INPUT_FILES="$(ls "${STATICS_PATH}" | grep input)"
readonly OUT="new_values.yaml"
readonly CURRENT_CHART_VERSION=$(yq r ${SCRIPT_PATH}/../../deploy/helm/sumologic/Chart.yaml version)

docker run --rm \
  -v ${SCRIPT_PATH}/../../deploy/helm/sumologic:/chart \
  sumologic/kubernetes-tools:master \
  helm dependency update /chart

SUCCESS=0
for input_file in ${INPUT_FILES}; do
  test_name=$(echo "${input_file}" | sed -e 's/.input.yaml$//g')
  output_file="${test_name}.output.yaml"

  sed -i "s/%CURRENT_CHART_VERSION%/${CURRENT_CHART_VERSION}/g" ${STATICS_PATH}/${output_file}

  test_start "${test_name}" ${input_file}
  docker run --rm \
    -v ${SCRIPT_PATH}/../../deploy/helm/sumologic:/chart \
    -v "${STATICS_PATH}/${input_file}":/values.yaml \
    sumologic/kubernetes-tools:master \
    helm template /chart -f /values.yaml \
      --namespace sumologic \
      --set sumologic.traces.enabled=true \
      --set sumologic.accessId='accessId' \
      --set sumologic.accessKey='accessKey' \
      -s templates/otelcol-configmap.yaml 2>/dev/null 1> "${OUT}"

  test_output=$(diff "${STATICS_PATH}/${output_file}" "${OUT}" | cat -te)
  rm "${OUT}"

  if [[ -n "${test_output}" ]]; then
    echo -e "\tOutput diff (${STATICS_PATH}/${output_file}):\n${test_output}"
    test_failed "${test_name}"
    SUCCESS=1
  else
    test_passed "${test_name}"
  fi
done

exit $SUCCESS
