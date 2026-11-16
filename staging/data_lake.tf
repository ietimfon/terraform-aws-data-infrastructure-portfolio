resource "aws_s3_bucket" "ingestion" {
  bucket = "group-21-staging-data-ingestion"

  tags = {
    Name        = "group_21_staging_data_ingestion"
    Group       = "21"
    Environment = "Staging"
    Project     = "CDE Data Infrastructure"
  }
}
