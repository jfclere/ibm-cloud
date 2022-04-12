# ibm-cloud
script to create openshift IBM cloud.
based on https://github.com/snowdrop/k8s-infra/blob/main/ibm-cloud/README.md

# to startup an openshift cluster:

Look to https://github.com/snowdrop/k8s-infra/blob/main/ibm-cloud/README.md
and create the VPC, then run the startup script
```bash
export IC_API_KEY=the_key
export IC_REGION=eu-de
export IC_USER=redhatuser
export IC_TYPE=oc
bash startup.sh
```

To use kubernetes add the export:
```bash
export IC_TYPE=ks
```

# to connect to the openshift cluster
```bash
ibmcloud oc cluster config --cluster  ${IC_USER}-cluster --admin
```
if the token has timeout relog to IBM cloud
```bash
ibmcloud login -r eu-de -u ${IC_USER}@redhat.com  --apikey ${IC_API_KEY} --sso
```

# remove all
```bash
bash cleanup.sh
```
