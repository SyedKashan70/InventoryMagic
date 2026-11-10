@isTest
public with sharing class OrderProductUnReservedTest {
    @TestSetup
    static void setupData(){
        //Creating Account
        Account account = D_TestDataFactory.createAccount('Test Account Family', true);
        
        //Creating Contact
        Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);
        
        //Creating Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false); 
        product.RecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByName().get('Non Serial Control').getRecordTypeId();
        product.Lodestone__Supplier__c = account.Id;
        insert product; 
        
        //Creating Standard PBE for Product
        PricebookEntry pbe = D_TestDataFactory.createPriceBookEntry(Test.getStandardPricebookId(), product.Id, true);
        
        //Creating Warehouse
        IMagic__Warehouse__c Warehouse = D_TestDataFactory.createWareHouse('Warehouse', true);
        
        //Creating Stocking Location
        IMagic__Stocking_Location__c stockingLocation = D_TestDataFactory.createStockingLocation('Stocking Location', Warehouse.Id, true);
        
        //Creating Order
        Order order = D_TestDataFactory.createOrder(account.Id, contact.Id, false);
        order.IMagic__Stocking_Location__c = stockingLocation.Id;
        order.IMagic__Warehouse__c = Warehouse.Id;
        order.Status = 'Open';
        insert order;   
        
        //Creating OrderItem
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id, product.Id, pbe.Id, false);
        orderItem.IMagic__Stocking_Location__c = stockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 5;
        orderItem.IMagic__PO_Quantity__c = 0;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        insert orderItem;
        
        //Creating Inventory
        IMagic__Inventory__c inventory = D_TestDataFactory.createInventory('Inventory', stockingLocation.Id, product.Id, false);
        inventory.IMagic__Quantity_on_Hand__c = 5;
        inventory.IMagic__Quantity_Reserved__c = 5;
        insert inventory; 
    }
    
    @isTest
    static void testGetProducts() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
        List<orderProductUnReserved.OrderLineWrapper> result = orderProductUnReserved.getProducts(order.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testUnReservedOrderProduct() {
        
        IMagic__Stocking_Location__c stl = [SELECT Id,Name FROM IMagic__Stocking_Location__c LIMIT 1];
        IMagic__Inventory__c inv = [SELECT Id,Name FROM IMagic__Inventory__c LIMIT 1];
        Order order = [SELECT Id FROM Order LIMIT 1];
        List<orderProductUnReserved.OrderLineWrapper> wrapperList = orderProductUnReserved.getProducts(order.Id);
        orderProductUnReserved.serialListWrapper srlwrp = new orderProductUnReserved.serialListWrapper();
        srlwrp.invDetailId =inv.Id;
        srlwrp.invDetailName = inv.name;
        
        
        for (orderProductUnReserved.OrderLineWrapper wrapper : wrapperList) {
            wrapper.newUnReservedQuantity = 2; // Setting some quantity to unreserve
            wrapper.quantityOrdered = 3;
            wrapper.orderId = order.Id;
            wrapper.stockingLocationId =stl.id;
            wrapper.stockingLocationName= stl.Name;
            wrapper.serialList = new list<orderProductUnReserved.serialListWrapper>{srlwrp};  
        }
        
        String jsonString = JSON.serialize(wrapperList);
        
        Test.startTest();
        String resultOrderId = orderProductUnReserved.unReservedOrderProduct(jsonString);
        Test.stopTest();
    }
}