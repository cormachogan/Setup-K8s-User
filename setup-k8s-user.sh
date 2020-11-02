#!/bin/sh

#----------------------------------------------------------------------------------------------------
#
#-- Create a local user on the K8s cluster to perform tasks restricted to his or her namespace
#
#-- Guidance taken from https://www.openlogic.com/blog/granting-user-access-your-kubernetes-cluster
#
#-- Author: Cormac J. Hogan
#
#-- Version 1.0 (02-Nov-2020)
#
#----------------------------------------------------------------------------------------------------

clear
echo
echo "--------------------------------------------------------------------------------------------------"
echo "This script will  create a user and a namespace in the current Kubernetes cluster context but will"
echo "restrict the ability of a particular user to perform tasks to their own namespace."
echo
echo "The user will not be allowed to look at any cluster wide objects, but instead will only be able"
echo "to create, monitor, manage and delete Kubernetes objects in their own namespace."
echo
echo "Prerequisites:"
echo " - kubectl"
echo " - openssl"
echo " - awk"
echo " - sed"
echo " - a running Kubernetes cluster"
echo
echo "Guidance:"
echo " - First run script without any command line options to understand the flow."
echo " - If satisifed it is working, run script with any additional command line option to skip enter"
echo "   key requirement."
echo
echo "--------------------------------------------------------------------------------------------------"
echo

echo "Type in the name of the user (e.g. bob): \c"
read user

if [ -z "$user" ]
then
	echo "no user supplied"
	exit
fi


echo "Type in the name of the namespace that the user showul work in (e.g. bob): \c"
read namespace

if [ -z "$namespace" ]
then
	echo "no namespace supplied"
	exit
fi

mycontext=`kubectl config current-context`

echo
echo "*** Current context is ${mycontext} ***"
echo

echo
echo
echo "*** Creating a new restricted namespace ${namespace} for user ${user} ***"
echo

echo
echo "-- Step 1: Delete older files from last run ..."
echo
rm ${user}-* 2>/dev/null

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi

echo
echo "-- Step 2: Create key and certificate signing request (CSR) for ${user} ..."
echo
openssl req -new -newkey rsa:4096 -nodes -keyout ${user}-k8s.key -out ${user}-k8s.csr -subj "/CN=${user}/O=devops" >/dev/null 2>&1

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 3: Create a CertificateSigningRequest manifest with the CSR generated in step 2 ..."
echo
cat << EOF >> ${user}-k8s-csr-tmp.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${user}-k8s-access
spec:
  groups:
  - system:authenticated
  request: CSR
  usages:
  - client auth
EOF

csr_output=`cat ${user}-k8s.csr | base64 | tr -d '\n'`

sed "s/CSR/${csr_output}/g" ${user}-k8s-csr-tmp.yaml >>  ${user}-k8s-csr.yaml


if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 4: Display newly created CSR manifest ${user}-k8s-csr.yaml"
echo
cat ${user}-k8s-csr.yaml
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 5: Create the CSR in Kubernetes ..."
echo
kubectl delete csr ${user}-k8s-access 2>/dev/null
kubectl create -f ${user}-k8s-csr.yaml
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 6: Check Status of CSR, currently not approved ..."
echo
kubectl get csr
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 7: Approve CSR ..."
echo
kubectl certificate approve ${user}-k8s-access
echo
kubectl get csr
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 8: Retrieve User Certificate from K8s and store locally in ${user}-k8s-access.crt ... "
echo
kubectl get csr ${user}-k8s-access -o jsonpath='{.status.certificate}' | base64 --decode > ${user}-k8s-access.crt
echo
cat ${user}-k8s-access.crt
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 9: Retrieve K8s Cluster CA Certificate and store locally in ${user}-k8s-ca.crt..."
echo
mycluster=`kubectl config get-contexts ${mycontext} --no-headers | awk '{print $3}'`
kubectl config view -o jsonpath="{.clusters[?(@.name == \"${mycluster}\")].cluster.certificate-authority-data}" --raw | base64 --decode - > ${user}-k8s-ca.crt
echo
cat  ${user}-k8s-ca.crt
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 10: Create ${user}'s KUBECONFIG using CA Certificate..."
echo
myserver=`kubectl config view -o jsonpath="{.clusters[?(@.name == \"${mycluster}\")].cluster.server}"`

#-- This command uses the --kubeconfig parameter to create the file ${user}-k8s-config
kubectl config set-cluster ${mycluster} --server=${myserver} --certificate-authority=${user}-k8s-ca.crt --kubeconfig=${user}-k8s-config --embed-certs

echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 11: Set user ${user} credentials using client key and cert ..."
echo
kubectl config set-credentials ${user} --client-certificate=${user}-k8s-access.crt --client-key=${user}-k8s.key --embed-certs --kubeconfig=${user}-k8s-config
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 12: Create a context for ${user}..."
echo
kubectl config set-context ${user} --cluster=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${mycluster}\")].name}") --namespace=${namespace} --user=${user} --kubeconfig=${user}-k8s-config
echo
kubectl config get-contexts --kubeconfig=${user}-k8s-config
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 13: Cleanup, Create and Label namespace (${namespace}) ..."
echo
kubectl delete ns ${namespace} 2>/dev/null
echo
kubectl create ns ${namespace}
echo
kubectl label ns bob user=${namespace}
echo
kubectl get ns
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 14: Set a context..."
echo
kubectl config use-context ${user} --kubeconfig=${user}-k8s-config
echo
kubectl config get-contexts --kubeconfig=${user}-k8s-config
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 15: Final Authentication Test..."
echo
kubectl version --kubeconfig=${user}-k8s-config
echo
echo "-- Congrats - ${user} is now authenticated but is not authorized to do anything. Let's fix that next..."
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 16: Authorization test 1 ... expected to not work..."
echo
kubectl get pods --kubeconfig=${user}-k8s-config
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 17: Create a RoleBinding to allow ${user} to do stuff in namespace ${namespace} ..."
echo
kubectl create rolebinding ${user}-admin --namespace=${namespace} --clusterrole=admin --user=${user}
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 18: Authorization test part deux ... should now work..."
echo
kubectl get pods --kubeconfig=${user}-k8s-config
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 19: Merge new config to .kube/config ..."
echo
kubectl config delete-context ${user} 2>/dev/null
echo
KUBECONFIG=~/.kube/config:${user}-k8s-config
kubectl config view --flatten >> ${user}-config-new.yaml
cp ${user}-config-new.yaml ~/.kube/config
echo
kubectl config use-context ${user}
echo
kubectl config get-contexts
