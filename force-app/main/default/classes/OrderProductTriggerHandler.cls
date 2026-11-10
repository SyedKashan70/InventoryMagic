public class OrderProductTriggerHandler {

    public static void updateOrderProducts(List<OrderItem> orderItemList) {
       try {
        List<OrderItem> orderItems_Update = new List<OrderItem>();
        Set<Id> warehouseIds = new Set<Id>();
        Map<Id, Id> warehouseToStockingLocationMap = new Map<Id, Id>();

        Set<Id> orderIds = new Set<Id>();
        for (OrderItem oi : orderItemList) {
            if (oi.OrderId != null) {
                orderIds.add(oi.OrderId);
            }
        }
        Map<Id, Order> orderMap = new Map<Id, Order>([SELECT Id, IMagic__Warehouse__c, IMagic__Stocking_Location__c FROM Order WHERE Id IN :orderIds]);

        for(Order ord : orderMap.values()){
            warehouseIds.add(ord.IMagic__Warehouse__c);
        }

        List<IMagic__Stocking_Location__c> relatedStockingLocation  = [SELECT Id,IMagic__Warehouse__c FROM IMagic__Stocking_Location__c WHERE
                                                               IMagic__Warehouse__c IN: warehouseIds AND IMagic__is_Main_Stocking_Location__c = true];
        for (IMagic__Stocking_Location__c stockingLocation : relatedStockingLocation) {
            warehouseToStockingLocationMap.put(stockingLocation.IMagic__Warehouse__c, stockingLocation.Id);
        }
        
        for (OrderItem orderItem : orderItemList) {
            Order relatedOrder = orderMap.get(orderItem.OrderId);
            if (relatedOrder != null) {
                OrderItem updatedOrderItem = new OrderItem();
                updatedOrderItem.Id = orderItem.Id;
                updatedOrderItem.IMagic__Warehouse__c = relatedOrder.IMagic__Warehouse__c;
                updatedOrderItem.IMagic__Stocking_Location__c = warehouseToStockingLocationMap.get(relatedOrder.IMagic__Warehouse__c);
                orderItems_Update.add(updatedOrderItem);
            }
        }
        update orderItems_Update;
       } catch (Exception e) {
        System.debug('e.getMessage() :: '+e.getMessage());
        throw new AuraHandledException('Error Updating Order Item ' + e.getMessage());
       }
    }
}