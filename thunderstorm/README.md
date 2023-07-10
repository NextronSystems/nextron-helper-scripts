# THOR Thunderstorm Helper Scripts

This folder contains scripts that help you with the installation and maintenance of THOR Thunderstorm. If you're looking for the Thunderstorm Collector or the collector scripts, find them in this dedicated [repository](https://github.com/NextronSystems/thunderstorm-collector).

## Thunderstorm Installer

The Thunderstorm installer scripts facilitate the installation of THOR Thunderstorm as service.

All you need is a valid [THOR thunderstorm "service" license](https://www.nextron-systems.com/thor-thunderstorm/).

All installer scripts include an "uninstall" function that completely removes all components after a testing phase.

### thunderstorm-installer Shell Script

A shell script for Linux.

#### Requirements

- bash
- wget
- unzip

Install them with:

```bash
sudo apt install wget unzip
```

or

```bash
sudo yum install wget unzip
```

#### Installation

The steps to install THOR Thunderstorm as a service are:

1. Save a "service" license to the current working directory
2. Switch you context to root `sudo -s`
3. Run `wget -O - https://raw.githubusercontent.com/NextronSystems/nextron-helper-scripts/master/thunderstorm/thunderstorm-installer.sh | bash`

Install Thunderstorm

```bash
sudo ./thunderstorm-installer.sh
```

Silent installation with no prompts

```bash
sudo ./thunderstorm-installer.sh auto
```

Uninstall Thunderstorm

```bash
sudo ./thunderstorm-installer.sh uninstall
```

You can get a complete setup guide from our support.

#### Tested On

Successfully tested on:

- Debian 10

## Thunderstorm Updater

The Thunderstorm updater script gets installed by Thunderstorm installer. You don't have to download it manually. If you download it manually, the usage examples below differ (`chmod +x thunderstorm-uupdate.sh` and add `.sh` extension to the commands). The Thunderstorm installer places this script as `thunderstorm-update` into the `/usr/local/sbin` folder. 

### Usage

Update signatures only. Manual service restart required.

```bash
sudo thunderstorm-update
```

Update THOR Thunderstorm binaries and signatures. Automatically stops and restarts the services after successfull update.

```bash
sudo thunderstorm-update full
```
