# Automatic Infrastructure Provisioning

[![Build Status](https://travis-ci.org/holderbaum/infrastructure.svg?branch=master)](https://travis-ci.org/holderbaum/infrastructure)

This repository contains the code to setup and test my personal server infrastructure.

## TODO

* Automatic Updates
* Automatic Backups
* IMAP/POP3 mail setup

## Testing

To test, simply call:

```
DIGITAL_OCEAN_API_TOKEN='...' ./go test
```

This command will create a new machine on digitalocean, run all the
provisioning scripts against it and then verify the correct setup using the
tests defined in the `spec/` folder.

Don't forget to remove the digitalocean machine afterwards using:

```
DIGITAL_OCEAN_API_TOKEN='...' ./go clean
```

## Production Deployment

Production deployment simply goes like this:

```
./go deploy
```

I deploy my infrastructure on a dedicated Hetzner machine. This machine is
initialized from rescue mode like this (copy & paste me):

```
{
  echo "DRIVE1 /dev/sda"
  echo "DRIVE2 /dev/sdb"
  echo
  echo "SWRAID 1"
  echo "SWRAIDLEVEL 1"
  echo
  echo "BOOTLOADER grub"
  echo "HOSTNAME turing.holderbaum.me"
  echo
  echo "PART /boot ext3  1G"
  echo "PART /     ext4 all"
  echo
  echo "IMAGE /root/images/Ubuntu-1604-xenial-64-minimal.tar.gz"
} > /autosetup
installimage
reboot
```
