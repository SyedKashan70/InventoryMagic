@isTest
public with sharing class StockTransferControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Warehouse
        IMagic__Warehouse__c sourceWarehouse = D_TestDataFactory.createWareHouse('Source Warehouse', true);
        IMagic__Warehouse__c destinationWarehouse = D_TestDataFactory.createWareHouse('Destination Warehouse', true);

        // Create Stocking Locations
        IMagic__Stocking_Location__c sourceStockingLocation = D_TestDataFactory.createMainStockingLocation('Source Stocking Location', sourceWarehouse.Id, true);
        IMagic__Stocking_Location__c destinationStockingLocation = D_TestDataFactory.createMainStockingLocation('Destination Stocking Location', destinationWarehouse.Id, true);

        // Create Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false);
        product.IMagic__Warehouse__c = sourceWarehouse.Id;
        insert product;

        // Create Inventory
        IMagic__Inventory__c sourceInventory = D_TestDataFactory.createInventory('Source Inventory', sourceStockingLocation.Id, product.Id, true);
        D_TestDataFactory.createInventory('Destination Inventory', destinationStockingLocation.Id, product.Id, true);

        // Create Inventory Detail
        D_TestDataFactory.createInventoryDetail(sourceInventory.Id, null, true);
    }

    @isTest
    static void testGetInventoryRecords() {
        IMagic__Inventory__c inventory = [SELECT Id, IMagic__Product__c, IMagic__Stocking_Location__c FROM IMagic__Inventory__c LIMIT 1];

        Test.startTest();
        IMagic__Inventory__c result = StockTransferController.getInventoryRecords(inventory.IMagic__Product__c, inventory.IMagic__Stocking_Location__c);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected inventory record to be returned');
    }

    @isTest
    static void testCreateStockTransfer_LineItem() {
        IMagic__Warehouse__c sourceWarehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1];
        IMagic__Warehouse__c destinationWarehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1 OFFSET 1];

        // Prepare stock transfer line wrapper data
        List<StockTransferController.stockTransferLineWrapper> lineWrappers = new List<StockTransferController.stockTransferLineWrapper>();

        StockTransferController.stockTransferLineWrapper lineWrapper = new StockTransferController.stockTransferLineWrapper();
        lineWrapper.selectedProductId = [SELECT Id FROM Product2 LIMIT 1].Id;
        lineWrapper.selectedProductName = [SELECT Name FROM Product2 LIMIT 1].Name;
        lineWrapper.sourceStockingLocationId = [SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1].Id;
        lineWrapper.destinationStockingLocationId = [SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1 OFFSET 1].Id;
        lineWrapper.sourceStockingLocationInventoryId = [SELECT Id FROM IMagic__Inventory__c LIMIT 1].Id;
        lineWrapper.transferQuantity = 10;
        lineWrapper.isSerialControlProduct = false;
        lineWrappers.add(lineWrapper);

        String transferJson = JSON.serialize(lineWrappers);

        Test.startTest();
        Id stockTransferId = StockTransferController.createStockTransfer_LineItem(sourceWarehouse.Id, destinationWarehouse.Id, false, transferJson);
        Test.stopTest();

        System.assertNotEquals(null, stockTransferId, 'Expected stock transfer to be created');
    }

    @isTest
    static void testInsertStockTransfer() {
        IMagic__Warehouse__c sourceWarehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1];
        IMagic__Warehouse__c destinationWarehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1 OFFSET 1];

        Test.startTest();
        IMagic__Stock_Transfer__c stockTransfer = StockTransferController.insertStockTransfer(sourceWarehouse.Id, destinationWarehouse.Id);
        Test.stopTest();

        System.assertNotEquals(null, stockTransfer.Id, 'Expected stock transfer record to be inserted');
    }

    @isTest
    static void testCreateInventory() {
        IMagic__Stocking_Location__c stockingLocation = [SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Test.startTest();
        IMagic__Inventory__c inventory = StockTransferController.createInventory('Test Inventory', stockingLocation.Id, product.Id);
        Test.stopTest();

        System.assertEquals('Test Inventory', inventory.Name, 'Expected inventory name to match');
    }

    @isTest
    static void testInitializeInventory() {
        // Query inventory and include all required fields
        IMagic__Inventory__c inventory = [
            SELECT Id, IMagic__Quantity_on_Hand__c, IMagic__Cost__c, IMagic__Quantity_Reserved__c, IMagic__Product__c, IMagic__Stocking_Location__c
            FROM IMagic__Inventory__c LIMIT 1
        ];

        // Prepare a map to initialize inventory
        Map<String, IMagic__Inventory__c> inventoryMap = new Map<String, IMagic__Inventory__c>();
        String key = inventory.IMagic__Stocking_Location__c + '::' + inventory.IMagic__Product__c;
        inventoryMap.put(key, inventory);

        // Test the initializeInventory method
        Test.startTest();
        IMagic__Inventory__c result = StockTransferController.initializeInventory(key, inventoryMap);
        Test.stopTest();

        // Assert that the inventory ID matches
        System.assertEquals(inventory.Id, result.Id, 'Expected initialized inventory ID to match the queried inventory ID');
    }
}