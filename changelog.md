# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Add a ``-Filter`` parameter to filter based on log message contents.
- Add a ``-Pattern`` parameter to filter based on log message contents.
- Add handling to automatically switch to/from a _FileSystem_ PSProvider when invoked, if not already in one.
- Add ``-AllLogs`` parameter to automatically detect all *.log files in the specified path rather than specifying logs with ``-LogName``.
- Improve handling of multi-line entries (application enforcement etc.)

## [0.3.0] - 2020-08-13

### Added

- Add ``-Count`` parameter to limit the amount of returned log events.

## [0.2.0] - 2020-08-12

### Added

- Add ``-Before`` and ``-After`` parameters to limit the time range of log events.

## [0.1.0] - 2020-08-04

### Added

- Spun-off ``Get-CCMLog`` from [PSGubbins](https://github.com/phlcrny/PSGubbins) module
