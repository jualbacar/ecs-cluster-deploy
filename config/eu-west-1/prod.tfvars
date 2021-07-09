# Variables for PROD environment

region = "eu-west-1"

application = "website"
environment = "PRO"

cidr_block = "10.0.0.0/16"

azs             = ["eu-west-1a", "eu-west-1c"]
private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]
public_subnets  = ["10.0.102.0/24", "10.0.104.0/24"]

asg_desired_size = 2
asg_max_size = 4
asg_instance_type = "t2.medium"
asg_cpu_target_value = 50

service_task_desired = 2
service_asg_requests_target_value = 500
service_asg_task_max = 10
