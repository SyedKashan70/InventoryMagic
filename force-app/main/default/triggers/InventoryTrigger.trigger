trigger InventoryTrigger on IMagic__Inventory__c (after insert,after update) {

    LodestoneGroup_DMLConfig__mdt setting = [SELECT Inventory_Trigger__c FROM LodestoneGroup_DMLConfig__mdt LIMIT 1];
    // Checking if the Order_Item_Trigger__c is enabled
    if(!setting.Inventory_Trigger__c){
        return;
    }

    Set<Id> productIds = new Set<Id>();
    if(Trigger.isAfter){
        if(Trigger.isInsert || Trigger.isUpdate){
            for(IMagic__Inventory__c inv : Trigger.new){
                if(inv.IMagic__Product__c != null){
                    productIds.add(inv.IMagic__Product__c);
                }
            }
        }
    }

    System.debug('productIds Inv Trigger '+productIds);
    if(!productIds.isEmpty()){
        InventoryTriggerHandler.handleInventory_Insert_Update(productIds);
    }
}