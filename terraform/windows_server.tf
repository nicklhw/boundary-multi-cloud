/*
https://gmusumeci.medium.com/how-to-deploy-a-windows-server-ec2-instance-in-aws-using-terraform-dd86a5dbf731
*/

# Define the data source for the Windows Server
data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }
}

/*
Set get_password_data to false to by-pass waiting for EC2 to generate an
admin password. Instead, use doormat session to SSM into the windows machine
and change the admin password manually using "net user Administrator NewPassword".
This workaround was needed because EC2 kept returning "password is not available"
error.

https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/common-messages.html#password-not-available
*/
resource "aws_instance" "windows_server" {
  ami                         = data.aws_ami.windows_2022.id
  instance_type               = "t2.small"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.boundary_poc.id]
  associate_public_ip_address = false
  source_dest_check           = false
  key_name                    = aws_key_pair.boundary_poc.key_name
  get_password_data           = false
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  tags = merge(
    { Name = "Boundary RDP Target" },
    var.aws_tags
  )
}