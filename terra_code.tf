provider "aws" {
  region  = "ap-south-1"
  profile = "gaurav"
}
variable "enter_ur_key_name" {
	type = string
	default = "mykey_ssh2"
}
resource "aws_security_group" "allow_ssh_httpd" {
  name        = "allow_ssh_httpd"
  description = "Allow TLS inbound traffic"
  vpc_id      = "<enter_your_vpcid>"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_httpd_ingress"
  }
}
resource "aws_s3_bucket" "cloud-task-1" {
  bucket = "cloud-task-1"
  acl    = "public-read"
  tags = {
    Name        = "s3_cloudfront"
    Environment = "Dev"
  }
  versioning {
    enabled = true
  }
}
output "domain_name" {
  value = "${aws_s3_bucket.cloud-task-1.bucket_regional_domain_name}"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.cloud-task-1.bucket_regional_domain_name}"
    origin_id   = "s3-task1"
	  custom_origin_config {
	    http_port = 80
	    https_port = 80
	    origin_protocol_policy = "match-viewer"
	    origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
	    }    
  }
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-task1"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }  
}
resource "aws_instance"  "web01" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name	= var.enter_ur_key_name
  security_groups =  [ "allow_ssh_httpd" ] 
  tags = {
    Name = "task1"
  }
  connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/gaura/Desktop/mykey_ssh2.pem")
      host     = aws_instance.web01.public_ip
  }  
  provisioner "remote-exec" {
       inline = [
         "sudo yum install httpd php git net-tools -y",
         "sudo systemctl start httpd",
         "sudo systemctl enable httpd",
      ]         
  }
}
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.web01.availability_zone
  size              = 1
  tags = {
    Name = "task1_ebs1"
  }
}
resource "aws_volume_attachment" "ebs1_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs1.id}"
  instance_id = "${aws_instance.web01.id}"
}
resource "null_resource" "nullremote-1"  {
	depends_on = [
	    aws_volume_attachment.ebs1_att,
	  ]
	  connection {
	    type     = "ssh"
	    user     = "ec2-user"
	    private_key = file("C:/Users/gaura/Desktop/mykey_ssh2.pem")
	    host     = aws_instance.web01.public_ip
	  }
	provisioner "remote-exec" {
	    inline = [
	      "sudo mkfs.ext4  /dev/xvdh",
	      "sudo mount  /dev/xvdh  /var/www/html",
	      "sudo rm -rf /var/www/html/*",
	      "sudo git clone https://github.com/Gaurav-2001/task1_cloud.git /var/www/html/"
	    ]
	  }
	}
resource "null_resource" "nulllocal-1"  {
	depends_on = [
	    null_resource.nullremote-1,
	  ]
	provisioner "local-exec" {
		    command = "chrome  ${aws_instance.web01.public_ip}"
	  	}
	}
