variable "do_token" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "Terraform Key"
  public_key = "${file("./tmp/test_rsa_id.pub")}"
}

resource "digitalocean_droplet" "test_machine" {
  image = "ubuntu-16-04-x64"
  name = "turing.example.org"
  region = "fra1"
  size = "4gb"
  ssh_keys = [ "${digitalocean_ssh_key.default.id}" ]
}

output "ip" {
  value = "${digitalocean_droplet.test_machine.ipv4_address}"
}

