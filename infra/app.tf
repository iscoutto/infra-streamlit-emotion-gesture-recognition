# application.tf

# NOTA: Este arquivo deve ser aplicado APÓS o vpc.tf, pois depende dos IDs dos recursos de rede.

# Obter informações da conta e região atuais da AWS
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}    

# Valor local para o ID da lista de prefixos do CloudFront
# Este valor foi obtido diretamente do comando da AWS CLI
locals {
  cloudfront_prefix_list_id = "pl-3b927c52"
}

# ----------------------------------------
# Grupos de Segurança
# ----------------------------------------

# Grupo de Segurança para o ALB
resource "aws_security_group" "streamlit_alb_sg" {
  name        = "StreamlitALBSecurityGroup-${var.unique_id}"
  description = "Allow port ${var.container_port} from CloudFront"
  vpc_id      = aws_vpc.streamlit_vpc.id

  ingress {
    protocol          = "tcp"
    from_port         = var.container_port
    to_port           = var.container_port
    prefix_list_ids   = [local.cloudfront_prefix_list_id]
  }

  egress {
    protocol          = "tcp"
    from_port         = var.container_port
    to_port           = var.container_port
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name = "StreamlitALBSecurityGroup-${var.unique_id}"
  }
}

# Grupo de Segurança para os contêineres ECS
resource "aws_security_group" "streamlit_container_sg" {
  name        = "StreamlitContainerSecurityGroup-${var.unique_id}"
  description = "Allow container traffic from ALB"
  vpc_id      = aws_vpc.streamlit_vpc.id

  ingress {
    protocol          = "tcp"
    from_port         = var.container_port
    to_port           = var.container_port
    security_groups   = [aws_security_group.streamlit_alb_sg.id]
  }

  egress {
    protocol          = "-1" # Permite todo o tráfego de saída
    from_port         = 0
    to_port           = 0
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name = "StreamlitContainerSecurityGroup-${var.unique_id}"
  }
}


# ----------------------------------------
# Papéis do IAM
# ----------------------------------------

# Papel de execução da tarefa ECS
resource "aws_iam_role" "streamlit_ecs_execution_role" {
  name               = "StreamlitExecutionRole-${var.unique_id}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# Anexar a política gerenciada do AWS ECSTaskExecutionRole
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.streamlit_ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Papel da tarefa ECS
resource "aws_iam_role" "streamlit_ecs_task_role" {
  name               = "StreamlitECSTaskRole-${var.unique_id}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# Política para o papel da tarefa
resource "aws_iam_policy" "task_policy" {
  name        = "TaskPolicy-${var.unique_id}"
  description = "IAM policy for the Streamlit ECS Task"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/streamlitapp/*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "kms:Decrypt"
        ]
        Resource = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"
      },
      {
        Effect   = "Allow"
        Action   = [
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      },
    ]
  })
}

# Anexar a política ao papel da tarefa
resource "aws_iam_role_policy_attachment" "task_role_policy_attachment" {
  role       = aws_iam_role.streamlit_ecs_task_role.name
  policy_arn = aws_iam_policy.task_policy.arn
}


# ----------------------------------------
# Logs e Definição da Tarefa ECS
# ----------------------------------------

resource "aws_cloudwatch_log_group" "streamlit_log_group" {
  name              = "StreamlitLogGroup-${var.unique_id}"
  retention_in_days = 7
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_ecs_task_definition" "streamlit_task" {
  family                   = "StreamlitTaskDefinition-${var.unique_id}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.streamlit_ecs_execution_role.arn
  task_role_arn            = aws_iam_role.streamlit_ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "ContainerDefinition-${var.unique_id}"
      image       = var.streamlit_image_uri
      cpu         = var.cpu
      memory      = var.memory
      essential   = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.streamlit_log_group.name
          "awslogs-region"        = "us-east-1" # Verifique se a região está correta
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ----------------------------------------
# Application Load Balancer (ALB)
# ----------------------------------------

resource "aws_lb" "streamlit_alb" {
  name                       = var.unique_id
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  security_groups            = [aws_security_group.streamlit_alb_sg.id]
  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = var.logging_bucket_name
    prefix  = "alb/logs"
    enabled = true
  }

  tags = {
    Name = var.unique_id
  }
}

resource "aws_lb_target_group" "streamlit_tg" {
  name        = var.unique_id
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.streamlit_vpc.id

  stickiness {
    enabled = true
    type    = "lb_cookie"
  }
}

resource "aws_lb_listener" "streamlit_http_listener" {
  load_balancer_arn = aws_lb.streamlit_alb.arn
  port              = var.container_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "403"
      message_body = "Access denied"
    }
  }
}

resource "aws_lb_listener_rule" "streamlit_listener_rule" {
  listener_arn = aws_lb_listener.streamlit_http_listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.streamlit_tg.arn
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = ["${var.unique_id}-*"] # O nome da stack é assumido como o nome do UniqueId
    }
  }
}


# ----------------------------------------
# Serviço ECS
# ----------------------------------------

resource "aws_ecs_service" "streamlit_service" {
  name            = "StreamlitECSService-${var.unique_id}"
  cluster         = aws_ecs_cluster.streamlit_cluster.id
  task_definition = aws_ecs_task_definition.streamlit_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_task_count
  
  network_configuration {
    subnets         = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
    security_groups = [aws_security_group.streamlit_container_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.streamlit_tg.arn
    container_name   = "ContainerDefinition-${var.unique_id}" # Conforme definido na task definition
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener_rule.streamlit_listener_rule
  ]
}


# ----------------------------------------
# AutoScaling
# ----------------------------------------

# Papel de autoscaling
resource "aws_iam_role" "streamlit_autoscaling_role" {
  name = "StreamlitAutoscalingRole-${var.unique_id}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "application-autoscaling.amazonaws.com"
        }
      }
    ]
  })
}

# Anexar a política de autoscaling
resource "aws_iam_role_policy_attachment" "autoscaling_role_policy_attachment" {
  role       = aws_iam_role.streamlit_autoscaling_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

resource "aws_appautoscaling_target" "streamlit_autoscaling_target" {
  min_capacity        = var.min_capacity
  max_capacity        = var.max_capacity
  resource_id         = "service/${aws_ecs_cluster.streamlit_cluster.id}/${aws_ecs_service.streamlit_service.name}"
  scalable_dimension  = "ecs:service:DesiredCount"
  service_namespace   = "ecs"
  role_arn            = aws_iam_role.streamlit_autoscaling_role.arn
}

resource "aws_appautoscaling_policy" "streamlit_autoscaling_policy" {
  name               = "AutoScalingPolicy-${var.unique_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streamlit_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.streamlit_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streamlit_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
    target_value       = var.autoscaling_target_value
  }
}

# ----------------------------------------
# CloudFront
# ----------------------------------------

resource "aws_cloudfront_distribution" "s3_distribution" {
  enabled = true
  
  origin {
    domain_name = aws_lb.streamlit_alb.dns_name
    origin_id   = aws_lb.streamlit_alb.id
    custom_origin_config {
      https_port = 443
      http_port = 80
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.streamlit_alb.id

    forwarded_values {
      query_string = true
      cookies {
        forward = "whitelist"
        whitelisted_names = ["token"]
      }
      query_string_cache_keys = ["code"]
    }

    viewer_protocol_policy = "https-only"
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}

# ----------------------------------------
# Outputs
# ----------------------------------------

output "cloudfront_url" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.id
}
