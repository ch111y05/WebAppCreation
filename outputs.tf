# Outputs
output "private_subnet_id" {
  description = "The ID of the created private subnet."
  value       = aws_subnet.hashi_private_subnet.id
}

output "public_subnet_id_1" {  # Renamed for clarity
  description = "The ID of the first created public subnet."
  value       = aws_subnet.hashi_public_subnet.id
}

output "public_subnet_id_2" {  # New output for the second public subnet
  description = "The ID of the second created public subnet."
  value       = aws_subnet.hashi_public_subnet_2.id
}

output "aws_internet_gateway_id" {
  description = "The ID of the Internet Gateway used for the public subnet."
  value       = aws_internet_gateway.hashi_internet_gateway.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway used for the private subnet."
  value       = aws_nat_gateway.hashi_nat_gateway.id
}

output "aws_security_group" {
  description = "The ID of the security group used for the EC2 instance."
  value       = aws_security_group.hashi_web_sg.id
}

output "dev_node_instance_id" {
  description = "The ID of the created EC2 instance."
  value       = aws_instance.dev_node.id
}