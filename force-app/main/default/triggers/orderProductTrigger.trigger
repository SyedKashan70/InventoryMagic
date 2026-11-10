trigger orderProductTrigger on OrderItem (after insert, after update) {

    LodestoneGroup_DMLConfig__mdt setting = [SELECT Order_Item_Trigger__c FROM LodestoneGroup_DMLConfig__mdt LIMIT 1];
    // Checking if the Order_Item_Trigger__c is enabled
    if(!setting.Order_Item_Trigger__c){
        return;
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        List<OrderItem> orderItemList = new List<OrderItem>();
        for (OrderItem orderItem : Trigger.new) {
            if (orderItem.IMagic__Stocking_Location__c == null || orderItem.IMagic__Warehouse__c == null) {
                orderItemList.add(orderItem);
            }
        }

        if (!orderItemList.isEmpty()) {
            OrderProductTriggerHandler.updateOrderProducts(orderItemList);
        }
    }
}