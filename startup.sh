#!/bin/bash

if [ -z "${IC_API_KEY}" ]; then
  echo "missing IC_API_KEY"
  exit 1
fi

if [ -z "${IC_REGION}" ]; then
  echo "missing IC_REGION"
  exit 1
fi

if [ -z "${IC_USER}" ]; then
  echo "PREFIX empty using ${USER}"
  IC_USER=${USER}
fi

echo "Using IC_API_KEY: ${IC_API_KEY}, IC_REGION: ${IC_REGION} and IC_USER $IC_USER}"

# Check for a cluster, if failed try to login...
ibmcloud oc cluster ls
if [ $? -ne 0 ]; then
  ibmcloud login -r ${IC_REGION} -u ${IC_USER}@redhat.com  --apikey ${IC_API_KEY} --sso
fi

ibmcloud oc cluster ls
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  exit 1
fi

# https://github.com/snowdrop/k8s-infra/tree/main/ibm-cloud/ansible
# has created the vpc for us
ibmcloud is vpc ${IC_USER}-vpc
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  echo "Make sure you run the ansible script with the right paramters..."
  echo "Check https://github.com/snowdrop/k8s-infra/tree/main/ibm-cloud"
  exit 1
fi

VPC_ID=`ibmcloud is vpc ${IC_USER}-vpc | grep ^ID | awk '{ print $2 }'`

# create the public gateway that is missing in the ansible script
ibmcloud is public-gateway-create ${IC_USER}-gateway $VPC_ID eu-de-1
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  ibmcloud is public-gateways
fi

SBN_ID=`ibmcloud is subnet ${IC_USER}-subnet  | grep ^ID | awk '{ print $2 }'`
GWY_ID=`ibmcloud is public-gateway ${IC_USER}-gateway | grep ^ID | awk '{ print $2 }'`
ibmcloud is subnet-update $SBN_ID --public-gateway-id $GWY_ID
ibmcloud resource service-instance-create ${IC_USER}-cos cloud-object-storage standard global -g Default
COS_ID=`ibmcloud resource service-instance ${IC_USER}-cos | grep ^ID | awk '{ print $2 }'`
ibmcloud oc cluster create vpc-gen2 \
  --name ${IC_USER}-cluster \
  --zone eu-de-1 \
  --version 4.7.30_openshift \
  --flavor bx2.4x16 \
  --workers 2 \
  --vpc-id ${VPC_ID} \
  --subnet-id ${SBN_ID} \
  --cos-instance ${COS_ID}
