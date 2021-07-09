terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

# VPC creation
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  cidr = var.cidr_block

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true

  tags = {
    Application = var.application
    Environment = var.environment
  }
}

# VPC endpoint for S3
module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id,module.security_group_asg.this_security_group_id]

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "s3-vpc-endpoint-${var.environment}", Environment = var.environment }
    }
  }
}

# S3 bucket creation

resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "random_string" "vm-name" {
  length  = 12
  upper   = false
  number  = false
  lower   = true
  special = false
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = lower("${var.application}-bucket-${var.environment}-${random_string.vm-name.result}")
  acl    = "private"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.mykey.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# ECS cluster creation

locals {
  ecs-cluster-name = "ECS-cluster-${var.environment}"
}
 
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "2.8.0"

  name = "ECS-cluster-${var.environment}"

  tags = {
    Environment = var.environment
  }
}

module "ecs-instance-profile" {
  source  = "terraform-aws-modules/ecs/aws//modules/ecs-instance-profile"
  version = "3.1.0"

  name = "ECS-cluster-${var.environment}-${var.region}"

  tags = {
    Environment = var.environment
  }
}


data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

module "security_group_asg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "asg-sg-${var.environment}"
  description = "Security group for the ingress traffic to the ASG"
  vpc_id      = module.vpc.vpc_id

  egress_rules        = ["all-all"]

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = module.security_group.this_security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "ASG-${local.ecs-cluster-name}"

  # Launch configuration
  lc_name = "LCv2-${local.ecs-cluster-name}"

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = var.asg_instance_type
  security_groups      = [module.security_group_asg.this_security_group_id]
  iam_instance_profile = module.ecs-instance-profile.iam_instance_profile_id
  user_data            = data.template_file.user_data_file.rendered

  # Auto scaling group
  asg_name                  = "ASG-${local.ecs-cluster-name}"
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 2
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_size
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = var.environment
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = local.ecs-cluster-name
      propagate_at_launch = true
    }
  ]
}

data "template_file" "user_data_file" {
  template = file("./templates/user-data.sh")

  vars = {
    cluster_name = local.ecs-cluster-name
  }
}

resource "aws_autoscaling_policy" "ecs-asg-auto-pol" {
  name = "ECS-cluster-${var.environment}-asg-auto-pol"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = module.asg.this_autoscaling_group_name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.asg_cpu_target_value
  }
}

# ALB and TG creation

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "alb-sg-${var.environment}"
  description = "Security group for the ingress traffic to the ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "alb-${var.application}-${var.environment}"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.security_group.this_security_group_id]

  # access_logs = {
  #   bucket = "my-alb-logs"
  # }

  target_groups = [
    {
      name_prefix      = "tg-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Application = var.application
    Environment = var.environment
  }
}

# ECS task definition

resource "aws_iam_policy" "s3-ecs-access-policy" {
  name = "ecs-task-${var.environment}-policy-${var.region}"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": [module.s3_bucket.s3_bucket_arn]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": ["s3:*Object","s3:PutObjectAcl","s3:GetObjectAcl"]
            "Resource": ["${module.s3_bucket.s3_bucket_arn}/*"]
        }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
    name = "ECS-cluster-${var.environment}-ecs_task_role_s3_rw-${var.region}"
    assume_role_policy = file("iam/ecs_task_role.json")
    managed_policy_arns = [aws_iam_policy.s3-ecs-access-policy.arn]
}

resource "aws_cloudwatch_log_group" "task_log_group" {
  name = "/ecs/nginx-fourthline"

  tags = {
    Application = var.application
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "nginx-web" {
  family = "nginx-fourthline"
  task_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx:latest",
    "essential": true,
    "portMappings": [
      {
        "hostPort": 0,
        "protocol": "tcp",
        "containerPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.task_log_group.name}",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "memory": 128,
    "cpu": 100
  }
]
EOF
}

# ECS service definition

resource "aws_iam_role" "ecs_service_role" {
    name = "ECS-cluster-${var.environment}-ecs_service_role-${var.region}"
    assume_role_policy = file("iam/ecs_role.json")
}

resource "aws_iam_policy_attachment" "ecs-svc-attach" {
  name       = "policy-attachment-ECS-cluster-${var.environment}-${var.region}"
  roles      = [aws_iam_role.ecs_service_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_ecs_service" "nginx" {
  name            = "nginx-fourthline"
  cluster         = module.ecs.this_ecs_cluster_id
  task_definition = aws_ecs_task_definition.nginx-web.arn
  desired_count   = var.service_task_desired
  iam_role        = aws_iam_role.ecs_service_role.arn
  depends_on      = [aws_iam_policy_attachment.ecs-svc-attach]
  health_check_grace_period_seconds = 30

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = "nginx"
    container_port   = 80
  }
}

# ECS service autoscaling

resource "aws_appautoscaling_target" "requests_per_target" {
  max_capacity = var.service_asg_task_max
  min_capacity = 2
  resource_id = "service/${module.ecs.this_ecs_cluster_name}/${aws_ecs_service.nginx.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "requests_per_target_policy" {
  name               = "requests_per_target_policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.requests_per_target.resource_id
  scalable_dimension = aws_appautoscaling_target.requests_per_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.requests_per_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label = "${module.alb.this_lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
    }

    target_value = var.service_asg_requests_target_value
  }
}
