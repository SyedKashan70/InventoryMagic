public with sharing class WarehouseController {
    @AuraEnabled
    public static Boolean getWarehouseExist() {
        // Query the main warehouse stocking location
        try {
            List<IMagic__Warehouse__c> warehouseList = [SELECT Id FROM IMagic__Warehouse__c];
            if(warehouseList.isEmpty()) {
                return false;
            }
            else {
                return true;    
            }
        } catch (Exception ex) {throw new AuraHandledException('Failed to get getWarehouseExist :: ' + ex.getMessage());}
    }
}