# Triplicity

A backup tool for the linux desktop.

Written on top of <a href="http://duplicity.nongnu.org/" target="_blank">duplicity</a>,
this tool pushes backups kept locally to secondary storage (currently, an attached disk).

## Features

* multiple primary backups (different directories can be backed up)
* multiple destinations per primary backup (e.g. a disk at home and one at the office)
* scheduled backups (1), (2)
* notifications

Notes:

(1) Duplicity supports a vast amount of options, so you have to provide a shell command which executes duplicity.

(2) A backup is currently made when the last backup is a certain amount of time ago. This is perfect for laptops.


## Status / Missing features

Triplicity can currently be considered alpha.

* no tests
* no way of configuration (have not decided on this yet)
* no installation instruction (need to figure this out)
* ridiculously small (and usually not configurable) time constants, to ease development and debugging

## Contributing

If you find a bug or have some improvement, this is highly appreciated. Please file a pull request on Github.

Please strip trailing whitespace and indent with two spaces. Source files should end in a newline. Well readable and (ruby-)idiomatic code is preferred.

## Getting started

Lacking configuration and installation, getting Triplicity up is a bit involved.

### Dependencies

* bundler
* duplicity

### Installation

If you haven't already install <a href="http://bundler.io/" target="_blank">bundler</a>, then run

```
bundle install
```

Copy test.rb.example to test.rb, modify for your needs and run

```
ruby -Ilib test.rb
```

(If you like you can use `pry` instead of `ruby`)

## License

Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>

All rights reserved.

This is free software with ABSOLUTELY NO WARRANTY.

You can redistribute it and/or modify it under the terms of the GNU General Public License version 2.
