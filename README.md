# Stable log lists for Motoko

## Overview

This module implements an array of linked lists, fully stored in memory regions.

Lists support entries with variable size from 0 to 65_535 bytes.

Lists **do not** support modifications of already added items and item deletion.

To use a list, client code must first allocate it using `allocateList`.
Each list is identified by a unique index — a consecutive natural number starting from 0.

### Links

The package is published on [MOPS](https://mops.one/stable-log-lists) and [GitHub](https://github.com/research-ag/stable-log-lists).

The API documentation can be found [here](https://mops.one/stable-log-lists/docs).

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

### Motivation

This module is suitable for storing big amount of records in the regions without affecting heap memory.
Can be used for logs, events history etc.

### Interface

```motoko
stable let log : StableLogLists.StableLogLists = StableLogLists.new();
```

## Usage

```motoko
let log : StableLogLists.StableLogLists = StableLogLists.new();

let logList0 = StableLogLists.allocateList(log);
let logList1 = StableLogLists.allocateList(log);

let dataBlob : Blob = "";
StableLogLists.append(log, logList0, dataBlob);

StableLogLists.values(log, logList0) |> Iter.toArray(_); // produces 1 item, dataBlob
StableLogLists.values(log, logList1) |> Iter.toArray(_); // produces empty array
```

### Install with mops

You need `mops` installed. In your project directory run:
```
mops add stable-log-lists
```

In the Motoko source file import the package as:
```
import StableLogLists "mo:stable-log-lists";
```

### Example

### Build & test

We need up-to-date versions of `node`, `moc` and `mops` installed.

Then run:
```
git clone git@github.com:research-ag/stable-log-lists.git
mops install
mops test
```

## Design

All data is managed using two growable regions: `indexTable` and `data`.

## Implementation notes

### Index table region

The index table stores metadata for each list. Each record is 24 bytes long,
and the record for list `N` starts at offset `24 * N`.

Index table record structure:

| Offset | Type  | Description                                                          |
|--------|-------|----------------------------------------------------------------------|
| 0      | Nat64 | Number of items in the list                                          |
| 8      | Nat64 | Pointer (offset in `data`) to the first item in the list (0 if none) |
| 16     | Nat64 | Pointer (offset in `data`) to the last item in the list (0 if none)  |

### Data region

The data region stores the actual list items.
It begins with a single reserved byte so that pointer value `0` can be used as a null pointer.

Each item is stored as a record with the following structure:

| Offset | Type  | Description                                          |
|--------|-------|------------------------------------------------------|
| 0      | Nat64 | Pointer to the previous item in the list (0 if none) |
| 8      | Nat64 | Pointer to the next item in the list (0 if none)     |
| 16     | Nat16 | Size of the data blob                                |
| 18     | Blob  | Actual item data                                     |

## Copyright

MR Research AG, 2023-2025

## Authors

Main author: Andy Gura

Contributors: Timo Hanke

## License 

Apache-2.0
