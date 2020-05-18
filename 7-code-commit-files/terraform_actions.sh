#!/bin/bash
set -e

echo "*********** Create or select workspace"
if [ $(terraform workspace list | grep -c "$WORKSPACE_NAME") -eq 0 ] ; then
  echo "Create new workspace $WORKSPACE_NAME"
  terraform workspace new $WORKSPACE_NAME
else
  echo "Switch to workspace $WORKSPACE_NAME"
  terraform workspace select $WORKSPACE_NAME
fi

if [ $TF_ACTION = "PLAN" ] 
then
  echo "Making directory"
  mkdir -p plans
fi

if [ $TF_ACTION = "PLAN" ]
then
  echo "Running plan"
  terraform plan -out vpc.tfplan > tf_output.txt
  aws s3 cp vpc.tfplan s3://$TF_BUCKET/plans/$WORKSPACE_NAME-vpc.tfplan
fi

if [ $TF_ACTION = "APPLY" ]
then
  echo "Running apply"
  aws s3 cp s3://$TF_BUCKET/plans/$WORKSPACE_NAME-vpc.tfplan vpc.tfplan
  terraform apply vpc.tfplan > tf_output.txt
fi

if [ $TF_ACTION = "DESTROY" ] 
then
  echo "Running destroy"
  terraform destroy -auto-approve > tf_output.txt
fi