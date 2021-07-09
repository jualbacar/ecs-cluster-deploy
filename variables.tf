variable "region" {
  description = "Region in which to deploy the AWS resources"
  default     = "eu-west-1"
  type        = string
}

variable "application" {
  description = "Tag - application"
  type        = string
}

variable "environment" {
  description = "Tag - environment"
  type        = string
}

variable "cidr_block" {
  description = "VPC network block"
  type        = string
}

variable "azs" {
  description = "Subnets regions"
  type        = list(string)
}

variable "private_subnets" {
  description = "VPC private subnet cidr's"
  type        = list(string)
}

variable "public_subnets" {
  description = "VPC public subnet cidr's"
  type        = list(string)
}

variable "asg_desired_size" {
  description = "Cluster autoscaling group desired instances"
  default     = 2
  type        = number
}

variable "asg_max_size" {
  description = "Cluster autoscaling group maximun number of instances"
  type        = number
}

variable "asg_instance_type" {
  description = "Cluster autoscaling group instance type"
  default     = "t2.micro"
  type        = string
}

variable "asg_cpu_target_value" {
  description = "Autoscaling group policy CPU target value - threshold"
  type        = number
}

variable "service_task_desired" {
  description = "Number of desired tasks running in the service"
  default     = 2
  type        = number
}

variable "service_asg_task_max" {
  description = "Maximum number of tasks running in the service"
  default     = 10
  type        = number
}

variable "service_asg_requests_target_value" {
  description = "Service autoscaling policy requests per target value - threshold"
  default     = 500
  type        = number
}