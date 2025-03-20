#!/usr/bin/env bash

# Copyright 2025 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

export CWD=$(pwd)

function cert_manager_deploy {
      oc apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml
      oc -n cert-manager wait --for condition=ready pod -l app.kubernetes.io/instance=cert-manager --timeout=2m
}

function lws_deploy {
    if [ -z "$RELEASE_IMAGE_LATEST" ]; then
      echo "RELEASE_IMAGE_LATEST is empty"
      exit 1
    fi
    if [ -z "$KUBECONFIG" ]; then
      echo "KUBECONFIG is empty"
      exit 1
    fi
    if [ -z "$NAMESPACE" ]; then
      echo "NAMESPACE is empty"
      exit 1
    fi

echo "apiVersion: config.lws.x-k8s.io/v1alpha1
kind: Configuration
internalCertManagement:
  enable: false
leaderElection:
  leaderElect: true" > "$CWD"/config/manager/controller_manager_config.yaml

    pushd "$CWD"/config/manager
      echo "Setting the kubernetes-sigs-lws image built from this version"
      # take the domain name of the cluster
      REGISTRY=$(echo "$RELEASE_IMAGE_LATEST" | awk -F'/' '{print $1}')
      IMAGE_TAG=$REGISTRY/$NAMESPACE/pipeline:kubernetes-sigs-lws
      $KUSTOMIZE edit set image controller="$IMAGE_TAG"
    popd

    pushd "$CWD"/config/crd
      echo "enabling cainjection_in_leaderworkersets.yaml for CRD"
      sed -i 's!#- path: patches/cainjection_in_leaderworkersets.yaml!- path: patches/cainjection_in_leaderworkersets.yaml!' "$CWD/config/crd/kustomization.yaml"
    popd

    pushd "$CWD"/config/default
      echo "Enabling cert-manager and prometheus and disabling internalcert management."
      sed -i '/^#replacements:/,/^$/ s/^#//' "$CWD"/config/default/kustomization.yaml
      sed -i 's!#- path: webhookcainjection_patch.yaml!- path: webhookcainjection_patch.yaml!' "$CWD/config/default/kustomization.yaml"
      $KUSTOMIZE edit add resource "../prometheus"
      $KUSTOMIZE edit add resource "../certmanager"
      $KUSTOMIZE edit remove resource "../internalcert"
    popd

    $KUSTOMIZE build "$CWD"/test/e2e/config | oc apply --server-side -f -
    oc wait deployment lws-controller-manager -n lws-system --for=condition=Available --timeout=5m
}

cert_manager_deploy
lws_deploy
$GINKGO --junit-report=junit.xml --output-dir="$ARTIFACTS" -v "$CWD"/test/e2e/...
