# Variables for PROD environment

region = "eu-west-3"

application = "website"
environment = "PRO"

cidr_block = "10.0.0.0/16"

azs             = ["eu-west-3a", "eu-west-3c"]
private_subnets = ["10.0.12.0/24", "10.0.13.0/24"]
public_subnets  = ["10.0.112.0/24", "10.0.113.0/24"]

asg_desired_size = 2
asg_max_size = 4
asg_instance_type = "t2.medium"
asg_cpu_target_value = 50

service_task_desired = 2
service_asg_requests_target_value = 500
service_asg_task_max = 10
