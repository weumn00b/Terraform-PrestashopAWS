output "ec2_public_ip" {
  value = aws_instance.prestashop_ec2.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.prestashop_db.address
}

output "s3_bucket_name" {
  value = aws_s3_bucket.media_bucket.bucket
}
