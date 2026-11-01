# A VPC with no internet gateway and an S3 gateway endpoint. Traffic to S3 stays on
# the private AWS network, which is the AWS equivalent of the Azure private
# endpoint. A gateway endpoint attaches to a route table and costs nothing.
resource "aws_vpc" "lab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cloud-iam-lab-vpc"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "cloud-iam-lab-private-rt"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.lab.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "cloud-iam-lab-s3-endpoint"
  }
}
