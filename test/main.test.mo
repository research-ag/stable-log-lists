import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Prim "mo:prim";
import Text "mo:base/Text";

import StableLogLists "../src";

// Helper function to convert Text to Blob
func textToBlob(t : Text) : Blob {
  Text.encodeUtf8(t);
};

// Helper function to convert Blob to Text
func blobToText(b : ?Blob) : Text {
  let ?d = b else Prim.trap("EMpty blob received");
  let ?t = Text.decodeUtf8(d) else Prim.trap("Could not decode text");
  t;
};

// ================== StableLogLists tests ==================

// Test creating a new StableLogLists instance
do {
  Prim.debugPrint("StableLogLists :: should create a new instance");
  let lists = StableLogLists.new();
  assert lists.listsAmount == 0;
  assert lists.totalRecords == 0;
  assert lists.dataLength == 1; // Initial data length is 1 (reserved byte)
};

// Test allocating a list
do {
  Prim.debugPrint("StableLogLists :: should allocate a new list");
  let lists = StableLogLists.new();
  let listIndex = StableLogLists.allocateList(lists);
  assert listIndex == 0;
  assert lists.listsAmount == 1;
  assert StableLogLists.size(lists, listIndex) == 0;
};

// Test appending data to a list
do {
  Prim.debugPrint("StableLogLists :: should append data to a list");
  let lists = StableLogLists.new();
  let listIndex = StableLogLists.allocateList(lists);

  let data1 = textToBlob("test data 1");
  StableLogLists.append(lists, listIndex, data1);
  assert StableLogLists.size(lists, listIndex) == 1;
  assert lists.totalRecords == 1;

  let data2 = textToBlob("test data 2");
  StableLogLists.append(lists, listIndex, data2);
  assert StableLogLists.size(lists, listIndex) == 2;
  assert lists.totalRecords == 2;
};

// Test retrieving values from a list
do {
  Prim.debugPrint("StableLogLists :: should retrieve values from a list in order");
  let lists = StableLogLists.new();
  let listIndex = StableLogLists.allocateList(lists);

  let data1 = textToBlob("test data 1");
  let data2 = textToBlob("test data 2");
  let data3 = textToBlob("test data 3");

  StableLogLists.append(lists, listIndex, data1);
  StableLogLists.append(lists, listIndex, data2);
  StableLogLists.append(lists, listIndex, data3);

  let values = StableLogLists.values(lists, listIndex);
  assert values.next() == ?data1;
  assert values.next() == ?data2;
  assert values.next() == ?data3;
  assert values.next() == null;
};

// Test retrieving values in reverse order
do {
  Prim.debugPrint("StableLogLists :: should retrieve values from a list in reverse order");
  let lists = StableLogLists.new();
  let listIndex = StableLogLists.allocateList(lists);

  let data1 = textToBlob("test data 1");
  let data2 = textToBlob("test data 2");
  let data3 = textToBlob("test data 3");

  StableLogLists.append(lists, listIndex, data1);
  StableLogLists.append(lists, listIndex, data2);
  StableLogLists.append(lists, listIndex, data3);

  let valuesRev = StableLogLists.valuesRev(lists, listIndex);
  assert valuesRev.next() == ?data3;
  assert valuesRev.next() == ?data2;
  assert valuesRev.next() == ?data1;
  assert valuesRev.next() == null;
};

// Test multiple lists
do {
  Prim.debugPrint("StableLogLists :: should handle multiple lists");
  let lists = StableLogLists.new();

  let listIndex1 = StableLogLists.allocateList(lists);
  let listIndex2 = StableLogLists.allocateList(lists);

  assert listIndex1 == 0;
  assert listIndex2 == 1;

  let data1 = textToBlob("list 1 data");
  let data2 = textToBlob("list 2 data");

  StableLogLists.append(lists, listIndex1, data1);
  StableLogLists.append(lists, listIndex2, data2);

  assert StableLogLists.size(lists, listIndex1) == 1;
  assert StableLogLists.size(lists, listIndex2) == 1;
  assert lists.totalRecords == 2;

  let values1 = StableLogLists.values(lists, listIndex1);
  let values2 = StableLogLists.values(lists, listIndex2);

  assert values1.next() == ?data1;
  assert values1.next() == null;

  assert values2.next() == ?data2;
  assert values2.next() == null;
};

// Test totalSize function
do {
  Prim.debugPrint("StableLogLists :: should report correct totalSize");
  let lists = StableLogLists.new();

  assert StableLogLists.totalSize(lists) == 0;

  let listIndex1 = StableLogLists.allocateList(lists);
  let listIndex2 = StableLogLists.allocateList(lists);

  StableLogLists.append(lists, listIndex1, textToBlob("data 1"));
  StableLogLists.append(lists, listIndex1, textToBlob("data 2"));
  StableLogLists.append(lists, listIndex2, textToBlob("data 3"));

  assert StableLogLists.totalSize(lists) == 3;
};

// Test memory statistics
do {
  Prim.debugPrint("StableLogLists :: should report memory statistics");
  let lists = StableLogLists.new();

  let listIndex = StableLogLists.allocateList(lists);
  StableLogLists.append(lists, listIndex, textToBlob("test data"));

  let stats = StableLogLists.memoryStats(lists);

  assert stats.totalRecords == 1;
  assert stats.bytesUsed > 0;
  assert stats.pages.indexTable > 0;
  assert stats.pages.data > 0;
};

// Test error handling for non-allocated list
do {
  Prim.debugPrint("StableLogLists :: should trap when accessing non-allocated list");
  let lists = StableLogLists.new();

  let listIndex = StableLogLists.allocateList(lists);

  // This should work
  StableLogLists.append(lists, listIndex, textToBlob("test data"));

  // These should trap, but we can't easily test trapping in Motoko
  // Uncomment to manually verify trapping behavior
  // StableLogLists.append(lists, listIndex + 1, textToBlob("should trap"));
  // let _ = StableLogLists.values(lists, listIndex + 1);
  // let _ = StableLogLists.valuesRev(lists, listIndex + 1);
};

// Test with larger data sets
do {
  Prim.debugPrint("StableLogLists :: should handle larger data sets");
  let lists = StableLogLists.new();
  let listIndex = StableLogLists.allocateList(lists);

  // Add 100 items
  for (i in Iter.range(0, 99)) {
    let data = textToBlob("data item #" # Nat.toText(i));
    StableLogLists.append(lists, listIndex, data);
  };

  assert StableLogLists.size(lists, listIndex) == 100;
  assert lists.totalRecords == 100;

  // Verify first and last items
  let values = StableLogLists.values(lists, listIndex);
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
