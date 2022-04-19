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

if [ -z "${IC_TYPE}" ]; then
  echo "missing IC_TYPE supported oc or ks"
  exit 1
fi

echo "Using IC_API_KEY: ${IC_API_KEY}, IC_REGION: ${IC_REGION}, IC_USER: ${IC_USER} and IC_TYPE: ${IC_TYPE}"
TYPE=oc
if [ ${IC_TYPE} != "oc" ]; then
  TYPE=ks
fi

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

# Create the vpc
ibmcloud is vpc-create ${IC_USER}-vpc
while true
do
  ibmcloud is vpc ${IC_USER}-vpc | grep ^Status | grep available
  if [ $? -eq 0 ]; then
    break
  fi
  echo "Waiting for vpc to be available"
  sleep 10
done
ibmcloud is vpc ${IC_USER}-vpc
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  exit 1
fi

VPC_ID=`ibmcloud is vpc ${IC_USER}-vpc | grep ^ID | awk '{ print $2 }'`

# create the public gateway that is missing in the ansible script
ibmcloud is public-gateway-create ${IC_USER}-gateway $VPC_ID ${IC_REGION}-1
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  ibmcloud is public-gateways
fi

# create the sub net
CIDR_BLOCK=`ibmcloud is vpc-address-prefixes ${IC_USER}-vpc | grep ${IC_REGION}-1 | awk ' { print $3 } '`
ibmcloud is subnet-create ${IC_USER}-subnet $VPC_ID ${IC_REGION}-1 --ipv4-cidr-block "${CIDR_BLOCK}"
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  ibmcloud is subnets
fi
while true
do
  ibmcloud is subnet ${IC_USER}-subnet | grep ^Status | grep available
  if [ $? -eq 0 ]; then
    break
  fi
  echo "Waiting for vpc to be available"
  sleep 10
done
SBN_ID=`ibmcloud is subnet ${IC_USER}-subnet  | grep ^ID | awk '{ print $2 }'`

# add the gateway
ibmcloud is public-gateway-create ${IC_USER}-gateway ${VPC_ID} ${IC_REGION}-1
GWY_ID=`ibmcloud is public-gateway ${IC_USER}-gateway | grep ^ID | awk '{ print $2 }'`

ibmcloud is subnet-update $SBN_ID --public-gateway-id $GWY_ID
if [ ${TYPE} == "oc" ]; then
  ibmcloud resource service-instance ${IC_USER}-cos
  if [ $? -ne 0 ]; then
    # creates it.
    ibmcloud resource service-instance-create ${IC_USER}-cos cloud-object-storage standard global -g Default
  fi
  COS_ID=`ibmcloud resource service-instance ${IC_USER}-cos | grep ^ID | awk '{ print $2 }'`
  # only the last version of minor version can be used.
  #  --version 4.7.30_openshift \
  # ibmcloud ks versions to get the version.
  oc_version=$(ibmcloud ks versions |grep "openshift (default)" |awk '{print $1}')
  ibmcloud oc cluster create vpc-gen2 \
    --name ${IC_USER}-cluster \
    --zone ${IC_REGION}-1 \
    --flavor bx2.4x16 \
    --workers 2 \
    --version ${oc_version} \
    --vpc-id ${VPC_ID} \
    --subnet-id ${SBN_ID} \
    --cos-instance ${COS_ID}
else
  ibmcloud ks cluster create vpc-gen2 \
    --name ${IC_USER}-cluster \
    --zone ${IC_REGION}-1 \
    --flavor bx2.4x16 \
    --workers 2 \
    --vpc-id ${VPC_ID} \
    --subnet-id ${SBN_ID}
fi
