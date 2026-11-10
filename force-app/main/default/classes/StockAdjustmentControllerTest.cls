@isTest
public with sharing class StockAdjustmentControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Warehouse
        IMagic__Warehouse__c sourceWarehouse = D_TestDataFactory.createWareHouse('Source Warehouse', true);
        
        // Create Stocking Location
        IMagic__Stocking_Location__c sourceStockingLocation = D_TestDataFactory.createMainStockingLocation('Source Stocking Location', sourceWarehouse.Id, true);
        
        // Create Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false);
        product.IMagic__Warehouse__c = sourceWarehouse.Id;
        insert product;
        
        // Create Inventory
        IMagic__Inventory__c sourceInventory = D_TestDataFactory.createInventory('Source Inventory', sourceStockingLocation.Id, product.Id, true);
        
        // Create Inventory Detail
        D_TestDataFactory.createInventoryDetail(sourceInventory.Id, null, true);
    }
    
    @isTest
    static void testGetMainWarehouseStockingLocation() {
        Test.startTest();
        IMagic__Stocking_Location__c result = StockAdjustmentController.getMainWarehouseStockingLocation();
        Test.stopTest();
    }
    
    @isTest
    static void testGetInventoryRecords() {
        Set<Id> inventoryIds = new Set<Id>();
        IMagic__Inventory__c sourceInventory = [SELECT Id FROM IMagic__Inventory__c LIMIT 1];
        inventoryIds.add(sourceInventory.Id);
        
        Test.startTest();
        Map<String, IMagic__Inventory__c> result = StockAdjustmentController.getInventoryRecords(inventoryIds);
        Test.stopTest();
        
        System.assert(result.containsKey(sourceInventory.Id), 'Inventory map should contain the inventory ID');
    }
    
    @isTest
    static void testInitializeInventory() {
        IMagic__Inventory__c sourceInventory = [SELECT Id, IMagic__Quantity_on_Hand__c, IMagic__Cost__c,IMagic__Quantity_Reserved__c FROM IMagic__Inventory__c LIMIT 1];
        Map<String, IMagic__Inventory__c> inventoryMap = new Map<String, IMagic__Inventory__c>();
        inventoryMap.put(sourceInventory.Id, sourceInventory);
        
        Test.startTest();
        IMagic__Inventory__c result = StockAdjustmentController.initializeInventory(sourceInventory.Id, inventoryMap);
        Test.stopTest();
        
        System.assertEquals(sourceInventory.Id, result.Id, 'Initialized inventory ID should match the source inventory ID');
    }
    
    @isTest
    static void testCreateStockAdjustmentLine() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1];
        IMagic__Stocking_Location__c stockingLocation = [SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1];
        IMagic__Stock_Adjustment__c adjustment = StockAdjustmentController.insertStockAdjustment(warehouse.Id, stockingLocation.Id);
        
        StockAdjustmentController.stockAdjustmentLineWrapper wrapper = new StockAdjustmentController.stockAdjustmentLineWrapper();
        wrapper.action = 'Add';
        wrapper.adjustmentReason = 'Test Reason';
       // wrapper.AdjustmenType = 'Increase +';
        wrapper.inventoryId = [SELECT Id FROM IMagic__Inventory__c LIMIT 1].Id;
        wrapper.productId = [SELECT Id FROM Product2 LIMIT 1].Id;
        wrapper.newQuantity = 10;
        wrapper.QuantityOnHand=10;
        
        Test.startTest();
        IMagic__Stock_Adjustment_Line__c adjustmentLine = StockAdjustmentController.createStockAdjustmentLine(wrapper, adjustment);
        Test.stopTest();
        
    }
    
    @isTest
    static void testCreateStockAdjustmentLineComplete() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1];
        IMagic__Stocking_Location__c stockingLocation = [SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1];
        
        //serialListWrapper
        StockAdjustmentController.serialListWrapper serialWrp =new StockAdjustmentController.serialListWrapper();
        serialWrp.invDetailId=[SELECT Id FROM IMagic__Inventory_Detail__c LIMIT 1].Id;
        serialWrp.invDetailName=[SELECT name FROM IMagic__Inventory_Detail__c LIMIT 1].name;
        
        //serialNumberWrapper
        StockAdjustmentController.serialNumberWrapper serialNoWrp =new StockAdjustmentController.serialNumberWrapper();
        serialNoWrp.purchaseOrderLineId='';
        serialNoWrp.serialNumber='2';
        
        List<StockAdjustmentController.stockAdjustmentLineWrapper> wrappers = new List<StockAdjustmentController.stockAdjustmentLineWrapper>();
        
        StockAdjustmentController.stockAdjustmentLineWrapper wrapper = new StockAdjustmentController.stockAdjustmentLineWrapper();
        wrapper.rowNumber = '1';
        wrapper.stockingLocationId=[SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1].id;
        wrapper.isSerialControlProduct =true;
        wrapper.inventoryName = [SELECT Id,Name FROM IMagic__Inventory__c LIMIT 1].name;
        wrapper.action = 'Add';
        wrapper.adjustmentReason = 'Test Adjustment';
       // wrapper.AdjustmenType = 'Increase +';
        wrapper.inventoryId = [SELECT Id FROM IMagic__Inventory__c LIMIT 1].Id;
        wrapper.productId = [SELECT Id FROM Product2 LIMIT 1].Id;
        wrapper.productName =[SELECT Name FROM Product2 LIMIT 1].Name;
        wrapper.newQuantity = 5;
        wrapper.QuantityOnHand=10;
        wrapper.serialList = new list<StockAdjustmentController.serialListWrapper>{serialWrp};
            wrapper.serialNumberList = new list<StockAdjustmentController.serialNumberWrapper>{serialNoWrp};
                wrappers.add(wrapper);
        
        Test.startTest();
        String serializedWrappers = JSON.serialize(wrappers);
        System.debug('Debug::wrapper '+serializedWrappers);
        StockAdjustmentController.createStockAdjustment_Line(warehouse.Id, stockingLocation.Id,serializedWrappers );
        Test.stopTest();
        
    }
    
    @isTest
    static void testInsertStockAdjustment() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1];
        IMagic__Stocking_Location__c stockingLocation = [SELECT Id FROM IMagic__Stocking_Location__c LIMIT 1];
        
        Test.startTest();
        IMagic__Stock_Adjustment__c adjustment = StockAdjustmentController.insertStockAdjustment(warehouse.Id, stockingLocation.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testCreateInventory() {
        IMagic__Inventory__c inventory = [SELECT Id, IMagic__Quantity_on_Hand__c FROM IMagic__Inventory__c LIMIT 1];
        StockAdjustmentController.stockAdjustmentLineWrapper wrapper = new StockAdjustmentController.stockAdjustmentLineWrapper();
        wrapper.action = 'Add';
        wrapper.newQuantity = 10;
        wrapper.inventoryId = inventory.Id;
        
        Test.startTest();
        IMagic__Inventory__c updatedInventory = StockAdjustmentController.createInventory(wrapper, inventory);
        Test.stopTest();
        
    }
}