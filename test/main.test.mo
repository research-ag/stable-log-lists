// @testmode wasi

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Prim "mo:prim";
import Text "mo:base/Text";

import LogLists "../src";

// Helper function to convert Text to Blob
func textToBlob(t : Text) : Blob {
  Text.encodeUtf8(t);
};

// Helper function to convert Blob to Text
func blobToText(b : ?Blob) : Text {
  let ?d = b else Prim.trap("Empty blob received");
  let ?t = Text.decodeUtf8(d) else Prim.trap("Could not decode text");
  t;
};

// ================== LogLists tests ==================

// Test creating a new LogLists instance
do {
  Prim.debugPrint("LogLists :: should create a new instance");
  let lists = LogLists.new();
  assert lists.listsAmount == 0;
  assert lists.totalRecords == 0;
  assert lists.dataLength == 1; // Initial data length is 1 (reserved byte)
};

// Test allocating a list
do {
  Prim.debugPrint("LogLists :: should create a new list");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);
  assert listIndex == 0;
  assert lists.listsAmount == 1;
  assert LogLists.size(lists, listIndex) == 0;
};

// Test appending data to a list
do {
  Prim.debugPrint("LogLists :: should append data to a list");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  let data1 = textToBlob("test data 1");
  LogLists.append(lists, listIndex, data1);
  assert LogLists.size(lists, listIndex) == 1;
  assert lists.totalRecords == 1;

  let data2 = textToBlob("test data 2");
  LogLists.append(lists, listIndex, data2);
  assert LogLists.size(lists, listIndex) == 2;
  assert lists.totalRecords == 2;
};

// Test retrieving values from a list
do {
  Prim.debugPrint("LogLists :: should retrieve values from a list in order");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  let data1 = textToBlob("test data 1");
  let data2 = textToBlob("test data 2");
  let data3 = textToBlob("test data 3");

  LogLists.append(lists, listIndex, data1);
  LogLists.append(lists, listIndex, data2);
  LogLists.append(lists, listIndex, data3);

  let values = LogLists.values(lists, listIndex);
  assert values.next() == ?data1;
  assert values.next() == ?data2;
  assert values.next() == ?data3;
  assert values.next() == null;
};

// Test retrieving values in reverse order
do {
  Prim.debugPrint("LogLists :: should retrieve values from a list in reverse order");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  let data1 = textToBlob("test data 1");
  let data2 = textToBlob("test data 2");
  let data3 = textToBlob("test data 3");

  LogLists.append(lists, listIndex, data1);
  LogLists.append(lists, listIndex, data2);
  LogLists.append(lists, listIndex, data3);

  let valuesRev = LogLists.valuesRev(lists, listIndex);
  assert valuesRev.next() == ?data3;
  assert valuesRev.next() == ?data2;
  assert valuesRev.next() == ?data1;
  assert valuesRev.next() == null;
};

// Test prepending data to a list
do {
  Prim.debugPrint("LogLists :: should prepend data to a list");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  let data1 = textToBlob("test data 1");
  LogLists.prepend(lists, listIndex, data1);
  assert LogLists.size(lists, listIndex) == 1;
  assert lists.totalRecords == 1;

  let data2 = textToBlob("test data 2");
  LogLists.prepend(lists, listIndex, data2);
  assert LogLists.size(lists, listIndex) == 2;
  assert lists.totalRecords == 2;

  let data3 = textToBlob("test data 3");
  LogLists.prepend(lists, listIndex, data3);
  assert LogLists.size(lists, listIndex) == 3;
  assert lists.totalRecords == 3;

  let values = LogLists.values(lists, listIndex);
  assert values.next() == ?data3;
  assert values.next() == ?data2;
  assert values.next() == ?data1;
  assert values.next() == null;
};

// Test single-item lists
do {
  Prim.debugPrint("LogLists :: append should initialize list");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  let data1 = textToBlob("test data");
  LogLists.append(lists, listIndex, data1);

  let values = LogLists.values(lists, listIndex);
  assert values.next() == ?data1;
  assert values.next() == null;

  let valuesRev = LogLists.values(lists, listIndex);
  assert valuesRev.next() == ?data1;
  assert valuesRev.next() == null;
};

do {
  Prim.debugPrint("LogLists :: prepend should initialize list");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  let data1 = textToBlob("test data");
  LogLists.prepend(lists, listIndex, data1);

  let values = LogLists.values(lists, listIndex);
  assert values.next() == ?data1;
  assert values.next() == null;

  let valuesRev = LogLists.values(lists, listIndex);
  assert valuesRev.next() == ?data1;
  assert valuesRev.next() == null;
};

// Test multiple lists
do {
  Prim.debugPrint("LogLists :: should handle multiple lists");
  let lists = LogLists.new();

  let listIndex1 = LogLists.createList(lists);
  let listIndex2 = LogLists.createList(lists);

  assert listIndex1 == 0;
  assert listIndex2 == 1;

  let data1 = textToBlob("list 1 data");
  let data2 = textToBlob("list 2 data");

  LogLists.append(lists, listIndex1, data1);
  LogLists.append(lists, listIndex2, data2);

  assert LogLists.size(lists, listIndex1) == 1;
  assert LogLists.size(lists, listIndex2) == 1;
  assert lists.totalRecords == 2;

  let values1 = LogLists.values(lists, listIndex1);
  let values2 = LogLists.values(lists, listIndex2);

  assert values1.next() == ?data1;
  assert values1.next() == null;

  assert values2.next() == ?data2;
  assert values2.next() == null;
};

// Test totalSize function
do {
  Prim.debugPrint("LogLists :: should report correct totalSize");
  let lists = LogLists.new();

  assert LogLists.totalSize(lists) == 0;

  let listIndex1 = LogLists.createList(lists);
  let listIndex2 = LogLists.createList(lists);

  LogLists.append(lists, listIndex1, textToBlob("data 1"));
  LogLists.append(lists, listIndex1, textToBlob("data 2"));
  LogLists.append(lists, listIndex2, textToBlob("data 3"));

  assert LogLists.totalSize(lists) == 3;
};

// Test memory statistics
do {
  Prim.debugPrint("LogLists :: should report memory statistics");
  let lists = LogLists.new();

  let listIndex = LogLists.createList(lists);
  LogLists.append(lists, listIndex, textToBlob("test data"));

  let stats = LogLists.memoryStats(lists);

  assert stats.totalRecords == 1;
  assert stats.bytesUsed > 0;
  assert stats.pages.indexTable > 0;
  assert stats.pages.data > 0;
};

// Test empty list behavior for values and valuesRev
do {
  Prim.debugPrint("LogLists :: should handle empty lists correctly");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  // Test values on empty list
  let values = LogLists.values(lists, listIndex);
  assert values.next() == null;

  // Test valuesRev on empty list
  let valuesRev = LogLists.valuesRev(lists, listIndex);
  assert valuesRev.next() == null;
};

// Test mixed operations (append then prepend, prepend then append)
do {
  Prim.debugPrint("LogLists :: should handle mixed append and prepend operations");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  // Append first, then prepend
  let data1 = textToBlob("first appended");
  LogLists.append(lists, listIndex, data1);

  let data2 = textToBlob("then prepended");
  LogLists.prepend(lists, listIndex, data2);

  // Check order
  let values1 = LogLists.values(lists, listIndex);
  assert values1.next() == ?data2;
  assert values1.next() == ?data1;
  assert values1.next() == null;

  // Create a new list for prepend-then-append test
  let listIndex2 = LogLists.createList(lists);

  // Prepend first, then append
  let data3 = textToBlob("first prepended");
  LogLists.prepend(lists, listIndex2, data3);

  let data4 = textToBlob("then appended");
  LogLists.append(lists, listIndex2, data4);

  // Check order
  let values2 = LogLists.values(lists, listIndex2);
  assert values2.next() == ?data3;
  assert values2.next() == ?data4;
  assert values2.next() == null;
};

// Test with different data sizes
do {
  Prim.debugPrint("LogLists :: should handle different data sizes");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  // Empty blob
  let emptyData = textToBlob("");
  LogLists.append(lists, listIndex, emptyData);

  // Small blob
  let smallData = textToBlob("small");
  LogLists.append(lists, listIndex, smallData);

  // Large blob (1KB of data)
  var largeText = "";
  for (i in Iter.range(0, 99)) {
    largeText := largeText # "0123456789";
  };
  let largeData = textToBlob(largeText);
  LogLists.append(lists, listIndex, largeData);

  // Verify all data is retrieved correctly
  let values = LogLists.values(lists, listIndex);
  assert values.next() == ?emptyData;
  assert values.next() == ?smallData;
  assert values.next() == ?largeData;
  assert values.next() == null;
};

// Test creating many lists
do {
  Prim.debugPrint("LogLists :: should handle creating many lists");
  let lists = LogLists.new();

  // Create 10 lists
  let listIndices = Array.init<Nat>(10, 0);
  for (i in Iter.range(0, 9)) {
    listIndices[i] := LogLists.createList(lists);
    assert listIndices[i] == i;
  };

  // Add data to each list
  for (i in Iter.range(0, 9)) {
    let data = textToBlob("list " # Nat.toText(i) # " data");
    LogLists.append(lists, i, data);
    assert LogLists.size(lists, i) == 1;
  };

  // Verify data in each list
  for (i in Iter.range(0, 9)) {
    let values = LogLists.values(lists, i);
    let expectedData = textToBlob("list " # Nat.toText(i) # " data");
    assert values.next() == ?expectedData;
    assert values.next() == null;
  };

  assert lists.listsAmount == 10;
  assert lists.totalRecords == 10;
};

// Test with larger data sets
do {
  Prim.debugPrint("LogLists :: should handle larger data sets");
  let lists = LogLists.new();
  let listIndex = LogLists.createList(lists);

  // Add 100 items
  for (i in Iter.range(0, 99)) {
    let data = textToBlob("data item #" # Nat.toText(i));
    LogLists.append(lists, listIndex, data);
  };

  assert LogLists.size(lists, listIndex) == 100;
  assert lists.totalRecords == 100;

  // Verify first and last items
  let values = LogLists.values(lists, listIndex);
  assert blobToText(values.next()) == "data item #0";

  // Skip to the end
  var item = values.next();
  while (item != null) {
    let lastItem = item;
    item := values.next();
    if (item == null) {
      assert blobToText(lastItem) == "data item #99";
    };
  };
};
