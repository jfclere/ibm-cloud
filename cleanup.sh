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

# Remove the cluster
ibmcloud oc cluster ls
if [ $? -ne 0 ]; then
  echo "Something is wrong aborting"
  exit 1
fi
ibmcloud oc cluster ls | grep ^${IC_USER}-cluster
if [ $? -eq 0 ]; then
  ibmcloud oc cluster rm -c ${IC_USER}-cluster -f --force-delete-storage
else
  echo "${IC_USER}-cluster not found"
fi

# remove the service instance
ibmcloud resource service-instance-delete ${IC_USER}-cos -f --recursive
if [ $? -ne 0 ]; then
  echo "Something wrong while deleting service-instance ${IC_USER}-cos"
  ibmcloud resource service-instances
fi

# remove the sub net
ibmcloud is subnet-delete ${IC_USER}-subnet -f
if [ $? -ne 0 ]; then
  echo "Something wrong while deleting subnet ${IC_USER}-net"
  ibmcloud is subnets
fi
# wait until it is delete
while true
do
  ibmcloud is subnet ${IC_USER}-subnet 2>&1 | grep 404
  if [ $? -eq 0 ]; then
    break
  fi
  sleep 10
  "Waiting for subnet ${IC_USER}-subnet to be rempoved"
done 

# remove the public gateway
ibmcloud is public-gateway-delete ${IC_USER}-gateway -f
if [ $? -ne 0 ]; then
  echo "Something wrong while deleting public gateway ${IC_USER}-gateway"
  ibmcloud is public-gateways
fi

# remove the IBM cloud
ibmcloud is vpcd ${IC_USER}-vpc -f
if [ $? -ne 0 ]; then
  echo "Something wrong while deleting public gateway ${IC_USER}-gateway"
  ibmcloud is public-gateways
fi
