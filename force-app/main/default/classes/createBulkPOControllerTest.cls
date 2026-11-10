@isTest
public with sharing class createBulkPOControllerTest {

    @TestSetup
    static void makeData() {
        // Create Account and Supplier Accounts
        Account account = D_TestDataFactory.createAccount('Test Account Family', false);
        account.IMagic__Terms__c = 'Net 10';
        insert account;
        
        Account supplierAccount1 = D_TestDataFactory.createAccount('Test Account Supplier 1', false);
        supplierAccount1.IMagic__Terms__c = 'Net 10';
        insert supplierAccount1;
        
        Account supplierAccount2 = D_TestDataFactory.createAccount('Test Account Supplier 2', false);
        supplierAccount2.IMagic__Terms__c = 'Net 10';
        insert supplierAccount2;

        // Create Warehouse and Stocking Location
        IMagic__Warehouse__c warehouse = D_TestDataFactory.createWareHouse('Warehouse', true);
        
        // Create Products with reorder and quantity on hand conditions
        Product2 product1 = D_TestDataFactory.createProduct('Test Product 1', false);
        product1.Lodestone__Quantity_On_Hand__c = 50;
        product1.Reorder_Quantity__c = 100;
        product1.Lodestone__Cost_Price__c = 20;
        product1.Lodestone__Sale_Price__c = 25;
        product1.IMagic__Profit_Margin__c = 10;
        product1.Lodestone__Supplier__c = supplierAccount1.Id;
        product1.IMagic__Warehouse__c = warehouse.Id;
        insert product1;

        Product2 product2 = D_TestDataFactory.createProduct('Test Product 2', false);
        product2.Lodestone__Quantity_On_Hand__c = 30;
        product2.Reorder_Quantity__c = 50;
        product2.Lodestone__Cost_Price__c = 20;
        product2.Lodestone__Sale_Price__c = 25;
        product2.IMagic__Profit_Margin__c = 10;
        product2.Lodestone__Supplier__c = supplierAccount2.Id;
        product2.IMagic__Warehouse__c = warehouse.Id;
        insert product2;

        Stocking_Location__c mainStockingLocation = D_TestDataFactory.createStockingLocation('Main Stocking Location', warehouse.Id, false);
        mainStockingLocation.is_Main_Stocking_Location__c = true;
        insert mainStockingLocation;
    }

    @isTest
    static void testGetProductList() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM IMagic__Warehouse__c WHERE Name = 'Warehouse' LIMIT 1];
        Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today().addDays(2);

        Test.startTest();
        List<Product2> productList = createBulkPOController.getProductList(warehouse.Id, startDate, endDate);
        Test.stopTest();

        System.assertNotEquals(null, productList, 'Product list should not be null');
    }

    @isTest
    static void testCreateBulkPurchaseOrders() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM IMagic__Warehouse__c WHERE Name = 'Warehouse' LIMIT 1];
        Stocking_Location__c mainStockingLocation = [SELECT Id FROM Stocking_Location__c WHERE is_Main_Stocking_Location__c = true LIMIT 1];

        String orderQuantitiesJson = '[{"ProductId": "' + [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1].Id + '", "OrderQuantity": 100},' +
                                     '{"ProductId": "' + [SELECT Id FROM Product2 WHERE Name = 'Test Product 2' LIMIT 1].Id + '", "OrderQuantity": 50}]';

        Test.startTest();
        createBulkPOController.createBulkPurchaseOrders(orderQuantitiesJson, warehouse.Id);
        Test.stopTest();

        List<Lodestone__Purchase_Order__c> purchaseOrders = [SELECT Id, Lodestone__Account__c, Status__c FROM Lodestone__Purchase_Order__c WHERE Status__c = 'Draft'];
        System.assertEquals(2, purchaseOrders.size(), 'Expected 2 purchase orders for two suppliers');

        List<Lodestone__Purchase_Order_Line__c> lineItems = [SELECT Id, Lodestone__Product__c, Lodestone__Quantity__c, Lodestone_Stocking_Location__c, Lodestone__Purchase_Order__c 
                                                      FROM Lodestone__Purchase_Order_Line__c 
                                                      WHERE Lodestone__Purchase_Order__c IN :purchaseOrders];
        System.assertEquals(2, lineItems.size(), 'There should be two purchase order line items created');
        for (Lodestone__Purchase_Order_Line__c item : lineItems) {
            System.assertEquals(mainStockingLocation.Id, item.Lodestone_Stocking_Location__c, 'Stocking location should match');
        }
    }
}