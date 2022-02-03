#!/bin/bash

# Read the zip and create a yaml to use to create the secret

# [jfclere@ovpn-113-163 TMP]$ unzip certificates.zip
#Archive:  certificates.zip
#   creating: jclere-cluster-0c576f1a70d464f092d8591997631748-0000_openshift-ingress/

DIR=`unzip certificates.zip | grep creating: | awk ' { print $2 } '`
KEY=`base64 -w 0 $DIR/*-ingress.key`
CERT=`base64 -w 0 $DIR/*-ingress.pem`
CHAIN=`base64 -w 0 $DIR/*-ingress_intermediate.pem`

# Create the yaml file
echo "apiVersion: v1" > tls-secret.yaml
echo "kind: Secret" >> tls-secret.yaml
echo "metadata:" >> tls-secret.yaml
echo "  name: tls-secret" >> tls-secret.yaml
echo "type: kubernetes.io/tls" >> tls-secret.yaml
echo "data:" >> tls-secret.yaml
echo "  tls.crt: ${CERT}" >> tls-secret.yaml
echo "  tls.key: ${KEY}" >> tls-secret.yaml
echo "  tls.chn: ${CHAIN}" >> tls-secret.yaml

if [ -d ${DIR} ]; then
  rm -rf ${DIR}
fi
