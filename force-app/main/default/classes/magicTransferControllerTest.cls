@isTest
public with sharing class magicTransferControllerTest {
    @TestSetup
    static void makeData(){
        //Creating Account
        Account account = D_TestDataFactory.createAccount('Test Account Family', true);

        //Creating Contact
        Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);

        //Creating Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false);
        product.RecordTypeId =  Schema.SObjectType.Product2.getRecordTypeInfosByName().get('Serial Control').getRecordTypeId();
        insert product; 
        Product2 newProduct = D_TestDataFactory.createProduct('Test Product', true); //Inventory don't exist

        //Creating Standard PBE for Product
        PricebookEntry pbe = D_TestDataFactory.createPriceBookEntry(Test.getStandardPricebookId(),product.Id,true);
        PricebookEntry pbe2 = D_TestDataFactory.createPriceBookEntry(Test.getStandardPricebookId(),newProduct.Id,true);

        //Creating Warehouse
        IMagic__Warehouse__c Warehouse = D_TestDataFactory.createWareHouse('Warehouse',true);

        //Creating Stocking Location
        IMagic__Stocking_Location__c StockingLocation = D_TestDataFactory.createStockingLocation('Stocking Location',Warehouse.Id,true);

        //Creating Stocking Location
        IMagic__Stocking_Location__c mainStockingLocation = D_TestDataFactory.createStockingLocation('Stocking Location',Warehouse.Id,false);
        mainStockingLocation.IMagic__is_Main_Stocking_Location__c = true;
        insert mainStockingLocation;

        //Creating Order
        Order order = D_TestDataFactory.createOrder(account.Id, contact.Id, false);
        order.IMagic__Stocking_Location__c = StockingLocation.Id;
        order.IMagic__Warehouse__c = Warehouse.Id;
        order.Status = 'Open';
        insert order;   


        //Creating OrderItem
        List<OrderItem> oiList = new List<OrderItem>();
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        
        oiList.add(orderItem);

        
        OrderItem orderItem2 = D_TestDataFactory.createOrderProduct(order.Id,pbe2.Id,newProduct.Id, false);
        orderItem2.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        
        oiList.add(orderItem2);
        insert oiList;

        order.Status = 'Awaiting Magic';
        update order;
        
        //Creating Inventory
        IMagic__Inventory__c sourceInventory = D_TestDataFactory.createInventory('Source Inventory',mainStockingLocation.Id,product.Id,true);
        IMagic__Inventory__c sourceInventory_newProduct = D_TestDataFactory.createInventory('Source new Product Inventory',mainStockingLocation.Id,newProduct.Id,true);
        IMagic__Inventory__c destinationInventory = D_TestDataFactory.createInventory('Destination Inventory',StockingLocation.Id,product.Id,true);

        //Creating Inventory Detail
        Inventory_Detail__c createInventoryDetail = D_TestDataFactory.createInventoryDetail(sourceInventory.Id,orderItem.Id,true);  
        Inventory_Detail__c createInventoryDetail2 = D_TestDataFactory.createInventoryDetail(sourceInventory_newProduct.Id,orderItem2.Id,true);  
    }

    @isTest
    static void testgetMainWarehouseStockingLocation() {
        Test.startTest();
        IMagic__Stocking_Location__c location = magicTransferController.getMainWarehouseStockingLocation();
        Test.stopTest();   
        Assert.isNotNull(location,'stocking location should not be null');
    }

    @isTest
    static void testprocessOrderProducts() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];
        IMagic__Stocking_Location__c sourceLocation = [SELECT Id FROM IMagic__Stocking_Location__c 
                                        WHERE IMagic__is_Main_Stocking_Location__c = true LIMIT 1];
        IMagic__Stocking_Location__c destinationLocation = [SELECT Id,Name FROM IMagic__Stocking_Location__c 
                                        WHERE IMagic__is_Main_Stocking_Location__c = false LIMIT 1];
        Test.startTest();
        Map<String,List<magicTransferController.magicTransferLineWrapper>> lines = magicTransferController.processOrderProducts(warehouse.Id,sourceLocation.Id,destinationLocation.Id,destinationLocation.Name);
        Test.stopTest();   
        Assert.isNotNull(lines,'lines should not be null');
    }

    @isTest
    static void testcreateStockTransfer_LineItem() {
        IMagic__Warehouse__c warehouse = [SELECT Id FROM IMagic__Warehouse__c LIMIT 1];
        Stocking_Location__c sourceLocation = [SELECT Id FROM IMagic__Stocking_Location__c 
                                        WHERE IMagic__is_Main_Stocking_Location__c = true LIMIT 1];
        IMagic__Stocking_Location__c destinationLocation = [SELECT Id,Name FROM IMagic__Stocking_Location__c 
                                        WHERE IMagic__is_Main_Stocking_Location__c = false LIMIT 1];
        Map<String,List<magicTransferController.magicTransferLineWrapper>> lines = magicTransferController.processOrderProducts(warehouse.Id,sourceLocation.Id,destinationLocation.Id,destinationLocation.Name);
        List<magicTransferController.magicTransferLineWrapper> allWrappers = new List<magicTransferController.magicTransferLineWrapper>();
        for (List<magicTransferController.magicTransferLineWrapper> wrapperList : lines.values()) {
            allWrappers.addAll(wrapperList);
        }
        String jsnString = JSON.serialize(allWrappers);

        Test.startTest();
        Id stockTransferId = magicTransferController.createMagicTransfer_LineItem(wareHouse.Id,jsnString);
        Test.stopTest();   
        Assert.isNotNull(stockTransferId,'lines should not be null');
    }
}