# THOR Thunderstorm Helper Scripts

This folder contains scripts that help you with the installation and maintenance of THOR Thunderstorm.

## Thunderstorm Installer

The Thunderstorm installer scripts facilitate the installation of THOR Thunderstorm as service.

All you need is a valid "service" license.

All installer scripts include an "uninstall" function that completely removes all components after a testing phase.

### thunderstorm-installer Shell Script

A shell script for Linux.

#### Requirements

- bash
- wget

#### Installation

The steps to install THOR Thunderstorm as a service are:

1. Save a "service" license to the current working directory
2. Switch you context to root `sudo -s`
3. Run `wget -O - https://raw.githubusercontent.com/NextronSystems/nextron-helper-scripts/master/thunderstorm/thunderstorm-installer.sh | bash`

#### Tested On

Successfully tested on:

- Debian 10

## Thunderstorm Collector Scripts

The Thunderstorm scripts have been moved to [this](https://github.com/NextronSystems/thunderstorm-collector/tree/master/scripts) new location. 