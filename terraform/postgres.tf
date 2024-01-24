resource "aws_instance" "postgres_target" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.boundary_poc.key_name
  associate_public_ip_address = false
  user_data_base64            = data.cloudinit_config.postgres.rendered
  user_data_replace_on_change = true
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.boundary_poc.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  tags = merge(
    { Name = "Boundary Postgres Target" },
    var.aws_tags
  )
}

/* Configuring postgress Database as per
https://developer.hashicorp.com/boundary/tutorials/credential-management/hcp-vault-cred-brokering-quickstart#setup-postgresql-northwind-demo-database
*/
data "cloudinit_config" "postgres" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      sudo apt-get install wget ca-certificates net-tools -y
      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
      sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
      sudo apt-get update
      # Installing Postgres version 15
      sudo apt-get install postgresql-15 postgresql-contrib git postgresql-client-common -y

      sudo sed -ibak "s/#listen_addresses\ \=\ 'localhost'/listen_addresses = '*'/g" /etc/postgresql/15/main/postgresql.conf
      sudo sed -ibak 's/127.0.0.1\/32/0.0.0.0\/0/g' /etc/postgresql/15/main/pg_hba.conf
      sudo echo "host    all             all             0.0.0.0/0                 md5" >> /etc/postgresql/15/main/pg_hba.conf
      sudo echo "host    all             all             ::/0                      md5" >> /etc/postgresql/15/main/pg_hba.conf

      sudo systemctl daemon-reload
      sudo systemctl restart postgresql.service
      sudo systemctl enable postgresql.service

      git clone https://github.com/hashicorp/learn-boundary-vault-quickstart

      sudo -i -u postgres createdb northwind
      sudo -i -u postgres psql -d northwind -f /learn-boundary-vault-quickstart/northwind-database.sql --quiet
      sudo -i -u postgres psql -d northwind -f /learn-boundary-vault-quickstart/northwind-roles.sql --quiet
      sudo -i -u postgres psql -U postgres -d postgres -c "alter user postgres with password '${var.postgres_password}';"

      curl 'https://api.ipify.org?format=txt' > /tmp/ip
      cat /tmp/ip
  EOF
  }
}