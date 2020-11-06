#!/bin/sh

#-------------------------------------------------------------------------------------------------------
#
#-- Remove a local user on the K8s cluster
#
#-- Guidance taken from https://www.openlogic.com/blog/granting-user-access-your-kubernetes-cluster
#
#-- Author: Cormac J. Hogan
#
#-- Version 1.0 (06-Nov-2020)
#
#-------------------------------------------------------------------------------------------------------

clear
echo
echo "--------------------------------------------------------------------------------------------------"
echo "This script will remove a user and a namespace in the current Kubernetes cluster context. "
echo
echo "The user was originally created by the accompanying script, setup-k8s-user.sh."
echo "Future plans will be to merge both scripts into a single entity with multiple options."
echo
echo "Prerequisites:"
echo " - kubectl"
echo " - a running Kubernetes cluster"
echo
echo "Guidance:"
echo " - First run script without any command line options to understand the flow."
echo " - If satisifed it is working, run script with any additional command line option to skip enter"
echo "   key requirement after every step, e.g. './remove-k8s-user.sh auto'"
echo
echo "--------------------------------------------------------------------------------------------------"
echo


function check_deps()
{
	which kubectl > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "kubectl is not installed, or is not in the PATH, exiting ..."
		exit
	fi
}

echo "-- Step 0: Checking dependencies ..."
check_deps

echo
echo "Type in the name of the user (e.g. bob): \c"
read user

if [ -z "$user" ]
then
	echo "no user supplied"
	exit
fi


echo "Type in the name of the namespace that the user has privilges in (e.g. bob-n): \c"
read namespace

if [ -z "$namespace" ]
then
	echo "no namespace supplied"
	exit
fi

mycontext=`kubectl config current-context`

echo
echo "*** Current context is ${mycontext}" 
echo "*** Deleting user ${user} in namespace ${namespace}"
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi

clear


echo
echo "-- Step 1: Delete the RoleBinding for ${user} to do stuff in namespace ${namespace} ..."
echo
kubectl delete rolebinding ${user}-admin --namespace=${namespace} --user=${user}
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 2: Delete the CSR in Kubernetes ..."
echo
kubectl delete csr ${user}-k8s-access 2>/dev/null
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 3: Cleanup namespace (${namespace}) ..."
echo
kubectl delete ns ${namespace} 2>/dev/null
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 4: Delete a context for ${user}..."
echo
kubectl config delete-context ${user}
echo

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


echo
echo "-- Step 5: Delete files for user ${user}  ..."
echo
rm ${user}-* 2>/dev/null

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi



echo
echo "-- Step 6: Check that namespace ${namespace} is now deleted ..."
echo
kubectl get ns

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi



echo
echo "-- Step 7: Check that config for user ${user} is now deleted ..."
echo
kubectl config get-contexts

if [ -z $1 ]
then
	echo "Hit enter to continue";read null
fi


