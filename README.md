# not_augeas

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with not_augeas](#setup)
    * [What not_augeas affects](#what-not_augeas-affects)
    * [Beginning with not_augeas](#beginning-with-not_augeas)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

The not_augeas module lets you modify files from multiple search / replace fragments.

## Module Description

The not_augeas module lets you gather `file_text` resources from your other modules
and compile those changes into a single resource to pass to puppets native
File Type.

## Setup

### What not_augeas affects

* Installs a new Puppet Type named file_text.

### Beginning with not_augeas

To start using not_augeas you need to create:
  * One or more file_text resources.

A minimal example might be:
~~~
  file_text { 'update_tmp_message':
    search  => 'Test message',
    replace => 'New Test message',
    path    => '/tmp/test_message',
  }
~~~


## Usage

The not_augeas manifests were provided as a convenience for use with hiera but
are not required.  You can see from the minimal example above how to use the
provided file_text puppet type within your own modules.

The examples within the `Usage` section will show configuration using hiera
leveraging the not_augeas manifests.

Assume we have a file `/tmp/test_message` with the following contents for
all examples listed within the `Usage`:
~~~
This is a test message
This is the second test message
Another second test message
This is Another second test message
This is the third test message
~~~

The following hiera configuration:
~~~
not_augeas:
  'update_test_message_1':
    path: '/tmp/test_message'
    search: 'message'
    replace: 'line'
~~~

Would yield the following results:
~~~
This is a test line
This is the second test line
Another second test line
This is Another second test line
This is the third test line
~~~

The following hiera configuraiton:
~~~
not_augeas:
  'update_test_message_1':
    path: '/tmp/test_message'
    search: 'message'
    match: 'second'
    replace: 'line'
~~~

Would yield the following results:
~~~
This is a test message
This is the second test line
Another second test line
This is Another second test line
This is the third test message
~~~

The following hiera configuraiton:
~~~
not_augeas:
  'update_test_message_1':
    path: '/tmp/test_message'
    search: 'message'
    match: 'Another second'
    replace: 'line'
~~~

Would yield the following results:
~~~
This is a test message
This is the second test message
Another second test line
This is Another second test line
This is the third test message
~~~

The following hiera configuraiton:
~~~
not_augeas:
  'update_test_message_1':
    path: '/tmp/test_message'
    search: 'message'
    match: '^Another second'
    replace: 'line'
~~~

Would yield the following results:
~~~
This is a test message
This is the second test message
Another second test line
This is Another second test message
This is the third test message
~~~

The following hiera configuraiton:
~~~
not_augeas:
  'update_test_message_1':
    path: '/tmp/test_message'
    search: 'This'
    replace: 'That'

  'update_test_message_2':
    path: '/tmp/test_message'
    search: 'message'
    match: '^Another second'
    replace: 'line'
~~~

Would yield the following results:
~~~
That is a test message
That is the second test message
Another second test line
That is Another second test message
That is the third test message
~~~

## Reference

Here, list the classes, types, providers, facts, etc contained in your module.
This section should include all of the under-the-hood workings of your module so
people know what the module is touching on their system but don't need to mess
with things. (We are working on automating this section!)

## Limitations

This module was tested on Open Source Puppet 4.x.
Resources with `match` must be done AFTER resources without `match` parameters.
This is a bug and will be addressed in a future revision.


## Development

The plan is to release this module to puppet forge.  If you can help to make
this module more awesome feel free to reach out to me.

## Contributors

Michael Beachler ([@michaelbeachler](http://twitter.com/michaelbeachler))

[More Contributors](https://github.com/michaelbeachler/not_augeas/graphs/contributors)
