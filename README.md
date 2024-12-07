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

### Difference from DeRez

DeRez is an Apple developer tool (tracing its lineage back to MPW) that creates a Rez source file describing the contents of one or more resources. DeRez's `-only` option can be used to extract only certain resources. 

DeRez always produces Rez source code. It is meant to be used for recovering a resource from a build artifact for comparison to original source, or replacement of that original source with a (Res)Edited version.

get1resource extracts the raw, binary contents of the resource. A hex-dump of its output will be the same as the hex-dump shown in ResEdit.
