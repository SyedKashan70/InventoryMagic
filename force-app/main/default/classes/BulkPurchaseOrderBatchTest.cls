@isTest
public class BulkPurchaseOrderBatchTest {
    public static TestMethod void UnitTest(){
        
        Account acc = new Account(Name ='ABC XYZ');
		String recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Vendor').getRecordTypeId(); 
        acc.RecordTypeId = recTypeId;
        insert acc;
		
        
        
        //Insert Warehouse
        IMagic__Warehouse__c warehouse = D_TestDataFactory.createWareHouse('Warehouse', true);
        
        IMagic__Stocking_Location__c mainStockingLocation = D_TestDataFactory.createStockingLocation('Main Stocking Location', warehouse.Id, false);
        mainStockingLocation.IMagic__is_Main_Stocking_Location__c = true;
        insert mainStockingLocation;
        
        Product2 product1 = D_TestDataFactory.createProduct('Test Product 1', false);
        product1.Lodestone__Quantity_On_Hand__c = 50;
        product1.Lodestone__Cost_Price__c = 20;
        product1.Lodestone__Sale_Price__c = 25;
        product1.IMagic__Profit_Margin__c = 10;
        product1.IMagic__Reorder_Quantity__c = 13;
        
        product1.IMagic__Warehouse__c = warehouse.Id;
        insert product1;
        
        Product2 product2 = D_TestDataFactory.createProduct('Test Product 2', false);
        product2.Lodestone__Quantity_On_Hand__c = 50;
        product2.IMagic__Reorder_Quantity__c = 13;
        product2.Lodestone__Cost_Price__c = 20;
        product2.Lodestone__Sale_Price__c = 25;
        product2.IMagic__Profit_Margin__c = 10;
        product2.Lodestone__Supplier__c =acc.id;
        product2.IMagic__Warehouse__c = warehouse.Id;
        insert product2;
        
        
        
       list<product2> prodlist = new list<product2>();
        prodlist.add(product1);
        prodlist.add(product2);
        
        String orderQuantitiesJson = '[{"ProductId": "' + [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1].Id + '", "OrderQuantity": 100},' +
            '{"ProductId": "' + [SELECT Id FROM Product2 WHERE Name = 'Test Product 2' LIMIT 1].Id + '", "OrderQuantity": 50}]';
        
        
        Database.BatchableContext bc;
        Test.StartTest();
        BulkPurchaseOrderBatch pobatch = new BulkPurchaseOrderBatch(orderQuantitiesJson,warehouse.id,mainStockingLocation.id);
        pobatch.start(bc);
        pobatch.execute(bc, prodlist);
        pobatch.finish(bc);
        Test.StopTest();
    }
    
}