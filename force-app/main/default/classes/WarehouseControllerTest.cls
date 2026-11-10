@isTest
public with sharing class WarehouseControllerTest {
    @isTest
    static void testgetWarehouseExist() {
        IMagic__Warehouse__c Warehouse = D_TestDataFactory.createWareHouse('Warehouse',true);
        Test.startTest();
        Boolean warehouseFound = WarehouseController.getWarehouseExist();
        Test.stopTest();
        System.Assert.areEqual(true, warehouseFound, 'Warehouse Exist');    
    }
    
    @isTest
    static void testgetWarehouseNotExist() {
        Test.startTest();
        Boolean warehouseFound = WarehouseController.getWarehouseExist();
        Test.stopTest();
        System.Assert.areEqual(false, warehouseFound, 'Warehouse Not Exist');    
    }
}