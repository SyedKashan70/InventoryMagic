trigger POLineTrigger on Lodestone__Purchase_Order_Line__c (after insert,after update) {

    LodestoneGroup_DMLConfig__mdt setting = [SELECT PO_Line_Trigger__c FROM LodestoneGroup_DMLConfig__mdt LIMIT 1];
    // Checking if the Order_Item_Trigger__c is enabled
    if(!setting.PO_Line_Trigger__c){
        return;
    }

    Set<Id> productIds = new Set<Id>();
    if(Trigger.isAfter){
        if(Trigger.isInsert || Trigger.isUpdate){
            for(Lodestone__Purchase_Order_Line__c poLine : Trigger.new){
                if(poLine.Lodestone__Product__c != null){
                    productIds.add(poLine.Lodestone__Product__c);
                }
            }
        }
    }

    System.debug('productIds :: '+productIds);
    if(!productIds.isEmpty()){
        POLineTriggerHandler.handlePOLine_Insert_Update(productIds);
    }
}