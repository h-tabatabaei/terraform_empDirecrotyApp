output "ec2_complete_public_ip" {
  description = "The public IP address assigned to the instance"
  value       = module.ec2-instance.public_ip
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = "http://${aws_lb.emp_alb.dns_name}"
}

output "s3_bucket_id" {
  description = "The name of the bucket."
  value       = module.s3-bucket.s3_bucket_id
}
