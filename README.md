# ECS-cluster-deploy
Deployment of an ECS cluster running a dummy service autoscaled in private subnet

This multi-region solution will deploy all the infrastructure needed to have an ECS cluster up and running. In the config folder you will find some config files examples for Ireland, Paris and Frankfurt region.

Every config file must be modified indicating your suitable values, for instance: region, subnets ranges, auto-scaling values, etc...

# Usage

* Create or modify the configuration file per region with all your custom values
* Run 'terraform init'
* Run 'terraform plan --var-file=./config/YOUR_REGION/CONFIG_FILE.tfvars'
* Run 'terraform apply --var-file=./config/YOUR_REGION/CONFIG_FILE.tfvars --auto-approve'

CONSIDERATIONS: you will have to use terraform workspaces in order to have separate working solutions per region. No need to do that if you are only going to test the solution.

This solution has been implemented with Terraform v0.14.3.


# Inputs and Outputs

## Parameters
Name | Default Value | Description |
--- | --- | --- |
| REGION | eu-west-1 | Region in which to deploy the AWS resources |
| APPLICATION | - | Tag - application
| ENVIRONMENT |	- | Tag - environment|
| CIDR_BLOCK | - | VPC network block |
| AZS |	- | Subnets regions |
| PRIVATE_SUBNETS | - | VPC private subnet cidr's |
| PUBLIC_SUBNETS | - | VPC public subnet cidr's |
| ASG_DESIRED_SIZE | 2 | Cluster autoscaling group desired instances |
| ASG_MAX_SIZE | - | Cluster autoscaling group maximun number of instances |
| ASG_INSTACE_TYPE | t2.micro | Cluster autoscaling group instance type |
| ASG_CPU_TARGET_VALUE | - | Autoscaling group policy CPU target value - threshold |
| SERVICE_TASK_DESIRED | 2 | Number of desired tasks running in the service |
| SERVICE_ASG_TASK_MAX | 10| Maximum number of tasks running in the service |
| SERVICE_ASG_REQUESTS_TARGET_VALUE | 500 | Service autoscaling policy requests per target value - threshold |

## Outputs
Name | Default Value | Description |
--- | --- | --- |
| ALB_DNS_NAME | - | Application load balancer DNS endpoint  |


