# get1resource
## A tool for extracting resources from Mac resource forks

This is a command-line tool for modern macOS that enables extracting one or more resources from a file containing a classic Mac OS resource fork (or a resource map in a data fork).

### Usage

    usage: get1Resource [options] input-file resource-type [resource-ID]

With a resource ID, extract that specified resource to a new file or stdout.  
Without a resource ID, extract all resources of that type.

Options:
- -`-help`	Print this text.
- `-useDF`	Read from the data fork of the `input-file`. Default is to read the resource fork.
- `-o OUTPUT_PATH`	Write output to `OUTPUT_PATH`. For one resource, this is a file; for all resources of a type, it is a folder to place output files in.
