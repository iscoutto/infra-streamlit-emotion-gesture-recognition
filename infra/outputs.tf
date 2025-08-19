# outputs.tf

# ----------------------------------------
# Outputs
# ----------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.streamlit_vpc.id
}

output "public_subnet_a_id" {
  description = "The ID of the public subnet in AZ A"
  value       = aws_subnet.public_subnet_a.id
}

output "public_subnet_b_id" {
  description = "The ID of the public subnet in AZ B"
  value       = aws_subnet.public_subnet_b.id
}

output "private_subnet_a_id" {
  description = "The ID of the private subnet in AZ A"
  value       = aws_subnet.private_subnet_a.id
}

output "private_subnet_b_id" {
  description = "The ID of the private subnet in AZ B"
  value       = aws_subnet.private_subnet_b.id
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = aws_ecs_cluster.streamlit_cluster.id
}
