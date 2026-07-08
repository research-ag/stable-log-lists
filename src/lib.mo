/// This module implements an array of linked lists, fully stored in memory regions.
/// All data is managed using two growable regions: `indexTable` and `data`.

/// To use a list, client code must first create it using `createList`.
/// Each list is identified by a unique index — a consecutive natural number starting from 0.

/// --- INDEX TABLE REGION ---
/// The index table stores metadata for each list. Each record is 24 bytes long,
/// and the record for list `N` starts at offset `24 * N`.

/// Index table record structure:
/// | Offset | Type  | Description                                                          |
/// |--------|-------|----------------------------------------------------------------------|
/// | 0      | Nat64 | Number of items in the list                                          |
/// | 8      | Nat64 | Pointer (offset in `data`) to the first item in the list (0 if none) |
/// | 16     | Nat64 | Pointer (offset in `data`) to the last item in the list (0 if none)  |

/// --- DATA REGION ---
/// The data region stores the actual list items.
/// It begins with a single reserved byte so that pointer value `0` can be used as a null pointer.

/// Each item is stored as a record with the following structure:
/// | Offset | Type  | Description                                          |
/// |--------|-------|------------------------------------------------------|
/// | 0      | Nat64 | Pointer to the previous item in the list (0 if none) |
/// | 8      | Nat64 | Pointer to the next item in the list (0 if none)     |
/// | 16     | Nat16 | Size of the data blob                                |
/// | 18     | Blob  | Actual item data                                     |
///
/// Copyright: 2025 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Blob "mo:core/Blob";
import { type Iter } "mo:core/Types";
import Nat "mo:core/Nat";
import Nat16 "mo:core/Nat16";
import Nat64 "mo:core/Nat64";
import Region "mo:core/Region";
import Runtime "mo:core/Runtime";

module {

  public type LogLists = {
    indexTable : Region;
    data : Region;
    var dataLength : Nat;
    var listsAmount : Nat;
    var totalRecords : Nat;
  };

  type Record = { prevPtr : Nat64; nextPtr : Nat64; data : Blob };

  public func new() : LogLists = {
    indexTable = Region.new();
    data = Region.new();
    var dataLength = 1;
    var listsAmount = 0;
    var totalRecords = 0;
  };

  public func size(l : LogLists, listIndex : Nat) : Nat {
    if (listIndex >= l.listsAmount) {
      Runtime.trap("Cannot retrieve size of list #" # debug_show listIndex # ". List was not created");
    };
    List(l, listIndex).length();
  };

  public func totalSize(l : LogLists) : Nat = l.totalRecords;

  public func createList(l : LogLists) : Nat {
    let newlistIndex = l.listsAmount;
    if (l.indexTable.size() * 65536 < (Nat64.fromNat(newlistIndex) + 1) * 24) {
      assert l.indexTable.grow(1) != 0xFFFF_FFFF_FFFF_FFFF;
    };
    l.listsAmount += 1;
    newlistIndex;
  };

  class List(l : LogLists, listIndex : Nat) {
    let r : Region = l.indexTable;
    let offset : Nat64 = Nat64.fromNat(3 * 8 * listIndex);

    public func head() : Nat64 = r.loadNat64(offset + 8);
    public func tail() : Nat64 = r.loadNat64(offset + 16);
    public func length() : Nat = r.loadNat64(offset).toNat();

    public func setHead(v : Nat64) = r.storeNat64(offset + 8, v);
    public func setTail(v : Nat64) = r.storeNat64(offset + 16, v);

    public func incLength() {
      r.loadNat64(offset)
      |> r.storeNat64(offset, _ + 1);
    };
  };

  public func append(l : LogLists, listIndex : Nat, data : Blob) {
    if (listIndex >= l.listsAmount) {
      Runtime.trap("Cannot append record to list #" # debug_show listIndex # ". List was not created");
    };
    if (data.size() > 65535) {
      Runtime.trap("Cannot append record: data size exceeds 65535 bytes");
    };
    let list = List(l, listIndex);
    let oldTail = list.tail();
    let newItem = addRecord_(l, { nextPtr = 0; prevPtr = oldTail; data });
    list.setTail(newItem);
    switch (oldTail) {
      case (0) list.setHead(newItem);
      case (_) storeNextPtr_(l, oldTail, newItem);
    };
    list.incLength();
    l.totalRecords += 1;
  };

  public func prepend(l : LogLists, listIndex : Nat, data : Blob) {
    if (listIndex >= l.listsAmount) {
      Runtime.trap("Cannot prepend record to list #" # debug_show listIndex # ". List was not created");
    };
    if (data.size() > 65535) {
      Runtime.trap("Cannot prepend record: data size exceeds 65535 bytes");
    };
    let list = List(l, listIndex);
    let oldHead = list.head();
    let newItem = addRecord_(l, { nextPtr = oldHead; prevPtr = 0; data });
    list.setHead(newItem);
    switch (oldHead) {
      case (0) list.setTail(newItem);
      case (_) storePrevPtr_(l, oldHead, newItem);
    };
    list.incLength();
    l.totalRecords += 1;
  };

  public func values(l : LogLists, listIndex : Nat) : Iter<Blob> {
    if (listIndex >= l.listsAmount) {
      Runtime.trap("Cannot retrieve values of list #" # debug_show listIndex # ". List was not created");
    };
    var ptr = List(l, listIndex).head();
    {
      next = func() : ?Blob {
        if (ptr == 0) return null;
        let { nextPtr; data } = loadDataRecord_(l.data, ptr);
        ptr := nextPtr;
        return ?data;
      };
    };
  };

  public func valuesRev(l : LogLists, listIndex : Nat) : Iter<Blob> {
    if (listIndex >= l.listsAmount) {
      Runtime.trap("Cannot retrieve valuesRev of list #" # debug_show listIndex # ". List was not created");
    };
    var ptr = List(l, listIndex).tail();
    {
      next = func() : ?Blob {
        if (ptr == 0) return null;
        let { prevPtr; data } = loadDataRecord_(l.data, ptr);
        ptr := prevPtr;
        return ?data;
      };
    };
  };

  public func memoryStats(l : LogLists) : {
    pages : { indexTable : Nat; data : Nat };
    bytesUsed : Nat;
    totalRecords : Nat;
  } = {
    pages = {
      indexTable = l.indexTable.size().toNat();
      data = l.data.size().toNat();
    };
    bytesUsed = l.dataLength;
    totalRecords = l.totalRecords;
  };

  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================
  private func loadDataRecord_(r : Region, offset : Nat64) : Record {
    let prevPtr = r.loadNat64(offset);
    let nextPtr = r.loadNat64(offset + 8);
    let size = r.loadNat16(offset + 16);
    let data = r.loadBlob(offset + 18, size.toNat());
    { data; prevPtr; nextPtr };
  };

  private func storeDataRecord_(r : Region, offset : Nat64, v : Record) {
    r.storeNat64(offset, v.prevPtr);
    r.storeNat64(offset + 8, v.nextPtr);
    r.storeNat16(offset + 16, v.data.size().toNat16());
    r.storeBlob(offset + 18, v.data);
  };

  private func addRecord_(l : LogLists, record : Record) : Nat64 {
    let len : Nat = l.dataLength;
    let newSize : Nat = record.data.size() + 18;
    while (l.data.size().toNat() * 65536 < len + newSize) {
      assert l.data.grow(1) != 0xFFFF_FFFF_FFFF_FFFF;
    };
    let offset = Nat64.fromNat(len);
    storeDataRecord_(l.data, offset, record);
    l.dataLength += newSize;
    offset;
  };

  private func storePrevPtr_(l : LogLists, recordPointer : Nat64, prevPtr : Nat64) = l.data.storeNat64(recordPointer, prevPtr);
  private func storeNextPtr_(l : LogLists, recordPointer : Nat64, nextPtr : Nat64) = l.data.storeNat64(recordPointer + 8, nextPtr);
  // ======================== INTERNAL PRIVATE FUNCTIONALITY ========================

};
